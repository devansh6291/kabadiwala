import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../models/lot_store.dart';
import '../models/lot.dart';
import '../services/backend_service.dart';
import '../services/sync_service.dart';

class EarningsLedgerScreen extends StatefulWidget {
  const EarningsLedgerScreen({super.key});

  @override
  State<EarningsLedgerScreen> createState() => _EarningsLedgerScreenState();
}

class _EarningsLedgerScreenState extends State<EarningsLedgerScreen> {
  late Future<List<Map<String, dynamic>>> _transactions;
  late Future<List<Map<String, dynamic>>> _payments;

  @override
  void initState() {
    super.initState();
    _transactions = BackendService().getCollectorTransactions();
    _payments = BackendService().getCollectorPayments();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Earnings ledger · कमाई')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _transactions,
          builder: (context, snapshot) {
            final transactions = snapshot.data ?? const [];
            final transactionLotIds = transactions
                .map((entry) => (entry['lotId'] ?? entry['lot_id'])?.toString())
                .whereType<String>()
                .toSet();
            final pendingLots = LotStore.getAllLots()
                .where((lot) => !transactionLotIds.contains(lot.id) && lot.paymentStatus != 'paid')
                .toList();
            final paidLocalLots = LotStore.getAllLots()
                .where((lot) => !transactionLotIds.contains(lot.id) && lot.paymentStatus == 'paid')
                .toList();
            final settled = transactions
                .where((entry) =>
                    ['paid', 'settled'].contains(
                        (entry['paymentStatus'] ?? entry['payment_status'])?.toString().toLowerCase()))
                .fold<double>(0, (sum, entry) => sum + _number(entry['finalPrice'] ?? entry['final_price'])) +
                paidLocalLots.fold<double>(0, (sum, lot) => sum + (lot.finalSaleValue ?? 0));
            final pending = pendingLots.fold<double>(
                0, (sum, lot) => sum + (lot.quotedPrice ?? lot.estimatedValue ?? 0));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: _summary('Received', settled, AppColors.primaryGreen)),
                  const SizedBox(width: 10),
                  Expanded(child: _summary('Pending estimate', pending, AppColors.primaryYellow)),
                ]),
                const SizedBox(height: 18),
                Text('Recorded transactions', style: Theme.of(context).textTheme.titleMedium),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No server-settled transactions yet. Saved lots remain available offline below.'),
                  ),
                ...transactions.map(_transactionCard),
                const SizedBox(height: 12),
                Text('Lots awaiting a recorded transaction', style: Theme.of(context).textTheme.titleMedium),
                ...pendingLots.map((lot) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text('${lot.category}${lot.subCategory == null ? '' : ' · ${lot.subCategory}'}'),
                        subtitle: Text('${lot.approxWeightKg.toStringAsFixed(1)} kg · ${DateFormat('d MMM, HH:mm').format(lot.createdAt)} · ${lot.syncStatus}'),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('~₹${(lot.quotedPrice ?? lot.estimatedValue ?? 0).toStringAsFixed(0)}'),
                          TextButton(onPressed: () => _recordPayment(lot), child: const Text('Record payment')),
                        ]),
                      ),
                    )),
                if (paidLocalLots.any((lot) => !lot.paymentSynced)) ...[
                  const SizedBox(height: 12),
                  Text('Payments recorded on this device · awaiting sync', style: Theme.of(context).textTheme.titleMedium),
                ...paidLocalLots.where((lot) => !lot.paymentSynced).map((lot) => ListTile(
                    leading: const Icon(Icons.check_circle, color: AppColors.success),
                    title: Text('${lot.category} · ${lot.paymentMethod ?? 'cash'}'),
                    subtitle: Text('Lot ${lot.id} · payment recorded on this device'),
                    trailing: Text('₹${(lot.finalSaleValue ?? 0).toStringAsFixed(0)}'),
                  )),
                ],
                const SizedBox(height: 12),
                Text('Synced payment records', style: Theme.of(context).textTheme.titleMedium),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _payments,
                  builder: (context, paymentSnapshot) {
                    final records = paymentSnapshot.data ?? const [];
                    if (records.isEmpty) return const Text('No synced payment records yet.');
                    return Column(children: records.map((record) => ListTile(
                      leading: const Icon(Icons.receipt_long, color: AppColors.success),
                      title: Text('${record['method'] ?? 'cash'} payment · Lot ${record['lotId'] ?? record['lot_id'] ?? ''}'),
                      subtitle: Text('${record['status'] ?? 'paid'} · ${record['recordedAt'] ?? record['recorded_at'] ?? ''}'),
                      trailing: Text('₹${_number(record['amount']).toStringAsFixed(0)}'),
                    )).toList());
                  },
                ),
              ],
            );
          },
        ),
      );

  Widget _summary(String title, double amount, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );

  Widget _transactionCard(Map<String, dynamic> entry) {
    final paid = ['paid', 'settled'].contains((entry['paymentStatus'] ?? entry['payment_status'])?.toString().toLowerCase());
    final amount = (paid ? (entry['finalPrice'] ?? entry['final_price']) : (entry['quotedPrice'] ?? entry['quoted_price'])) as num?;
    return Card(
      child: ListTile(
        leading: Icon(paid ? Icons.check_circle : Icons.pending_actions,
            color: paid ? AppColors.success : AppColors.pending),
        title: Text('Lot ${entry['lotId'] ?? entry['lot_id'] ?? '—'}'),
        subtitle: Text('${entry['transactionStatus'] ?? entry['transaction_status'] ?? 'recorded'} · ${paid ? 'Paid' : 'Payment pending'} · ${entry['paymentStatus'] ?? entry['payment_status'] ?? 'unpaid'}'),
        trailing: Text('₹${amount?.toStringAsFixed(0) ?? '0'}'),
      ),
    );
  }

  Future<void> _recordPayment(Lot lot) async {
    final controller = TextEditingController(text: (lot.quotedPrice ?? lot.estimatedValue ?? 0).toStringAsFixed(0));
    String method = 'cash';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Record a payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount received (₹)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'Method'), items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'digital', child: Text('Digital (optional)')),
          ], onChanged: (value) { if (value != null) setDialogState(() => method = value); }),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final amount = double.tryParse(controller.text);
          if (amount != null && amount >= 0) Navigator.pop(context, {'amount': amount, 'method': method});
        }, child: const Text('Save payment'))],
      )),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    await LotStore.updateLot(lot.copyWith(
      quotedPrice: result['amount'] as double,
      finalSaleValue: result['amount'] as double,
      paymentStatus: 'paid',
      paymentMethod: result['method'] as String,
    ));
    await SyncService().syncPendingLots();
    _payments = BackendService().getCollectorPayments();
    setState(() {});
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;
}
