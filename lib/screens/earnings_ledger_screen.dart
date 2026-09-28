import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/lot_store.dart';
import '../models/lot.dart';
import '../models/collector_store.dart';
import '../services/backend_service.dart';
import '../services/sync_service.dart';
import '../widgets/transaction_qr_button.dart';

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
                .where((lot) =>
                    !transactionLotIds.contains(lot.id) &&
                    lot.paymentStatus != 'paid')
                .toList();
            final paidLocalLots = LotStore.getAllLots()
                .where((lot) =>
                    !transactionLotIds.contains(lot.id) &&
                    lot.paymentStatus == 'paid')
                .toList();
            final settled = transactions
                    .where((entry) => ['paid', 'settled'].contains(
                        (entry['paymentStatus'] ?? entry['payment_status'])
                            ?.toString()
                            .toLowerCase()))
                    .fold<double>(
                        0,
                        (sum, entry) =>
                            sum +
                            _number(
                                entry['finalPrice'] ?? entry['final_price'])) +
                paidLocalLots.fold<double>(
                    0, (sum, lot) => sum + (lot.finalSaleValue ?? 0));
            final pending = pendingLots.fold<double>(
                0,
                (sum, lot) =>
                    sum + (lot.quotedPrice ?? lot.estimatedValue ?? 0));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(
                      child: _summary(
                          'Received', settled, AppColors.primaryGreen)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _summary('Pending estimate', pending,
                          AppColors.primaryYellow)),
                ]),
                const SizedBox(height: 18),
                Text('Recorded transactions',
                    style: Theme.of(context).textTheme.titleMedium),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'No server-settled transactions yet. Saved lots remain available offline below.'),
                  ),
                ...transactions.map(_transactionCard),
                const SizedBox(height: 12),
                Text('Lots awaiting a recorded transaction',
                    style: Theme.of(context).textTheme.titleMedium),
                ...pendingLots.map((lot) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(
                            '${lot.category}${lot.subCategory == null ? '' : ' · ${lot.subCategory}'}'),
                        subtitle: Text(
                            '${lot.approxWeightKg.toStringAsFixed(1)} kg · ${DateFormat('d MMM, HH:mm').format(lot.createdAt)} · ${lot.syncStatus}'),
                        trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '~₹${(lot.quotedPrice ?? lot.estimatedValue ?? 0).toStringAsFixed(0)}'),
                              TextButton(
                                  onPressed: () => _recordPayment(lot),
                                  child: const Text('Record payment')),
                            ]),
                      ),
                    )),
                if (paidLocalLots.any((lot) => !lot.paymentSynced)) ...[
                  const SizedBox(height: 12),
                  Text('Payments recorded on this device · awaiting sync',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...paidLocalLots
                      .where((lot) => !lot.paymentSynced)
                      .map((lot) => ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: AppColors.success),
                            title: Text(
                                '${lot.category} · ${lot.paymentMethod ?? 'cash'}'),
                            subtitle: Text(
                                'Lot ${lot.id} · payment recorded on this device'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                  '₹${(lot.finalSaleValue ?? 0).toStringAsFixed(0)}'),
                              _lotQrButton(lot),
                            ]),
                          )),
                ],
                const SizedBox(height: 12),
                Text('Synced payment records',
                    style: Theme.of(context).textTheme.titleMedium),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _payments,
                  builder: (context, paymentSnapshot) {
                    final records = paymentSnapshot.data ?? const [];
                    if (records.isEmpty)
                      return const Text('No synced payment records yet.');
                    return Column(
                        children: records
                            .map((record) => ListTile(
                                  leading: const Icon(Icons.receipt_long,
                                      color: AppColors.success),
                                  title: Text(
                                      '${record['method'] ?? 'cash'} payment · Lot ${record['lotId'] ?? record['lot_id'] ?? ''}'),
                                  subtitle: Text(
                                      '${record['status'] ?? 'paid'} · ${record['recordedAt'] ?? record['recorded_at'] ?? ''}'),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            '₹${_number(record['amount']).toStringAsFixed(0)}'),
                                        TransactionQrButton(
                                            transaction:
                                                _paymentPayload(record)),
                                      ]),
                                ))
                            .toList());
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text('₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );

  Widget _transactionCard(Map<String, dynamic> entry) {
    final paid = ['paid', 'settled'].contains(
        (entry['paymentStatus'] ?? entry['payment_status'])
            ?.toString()
            .toLowerCase());
    final amount = (paid
        ? (entry['finalPrice'] ?? entry['final_price'])
        : (entry['quotedPrice'] ?? entry['quoted_price'])) as num?;
    return Card(
      child: ListTile(
        leading: Icon(paid ? Icons.check_circle : Icons.pending_actions,
            color: paid ? AppColors.success : AppColors.pending),
        title: Text('Lot ${entry['lotId'] ?? entry['lot_id'] ?? '—'}'),
        subtitle: Text(
            '${entry['transactionStatus'] ?? entry['transaction_status'] ?? 'recorded'} · ${paid ? 'Paid' : 'Payment pending'} · ${entry['paymentStatus'] ?? entry['payment_status'] ?? 'unpaid'}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('₹${amount?.toStringAsFixed(0) ?? '0'}'),
          TransactionQrButton(transaction: _serverTransactionPayload(entry)),
        ]),
      ),
    );
  }

  Future<void> _recordPayment(Lot lot) async {
    final controller = TextEditingController(
        text: (lot.quotedPrice ?? lot.estimatedValue ?? 0).toStringAsFixed(0));
    String method = 'cash';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Record a payment'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount received (₹)')),
                  const SizedBox(height: 12),
                  const Text('Cash is accepted. Digital payment is optional.'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                            value: 'digital',
                            child: Text('Digital (optional)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => method = value);
                      }),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final amount = double.tryParse(controller.text);
                        if (amount != null && amount >= 0)
                          Navigator.pop(
                              context, {'amount': amount, 'method': method});
                      },
                      child: const Text('Save payment'))
                ],
              )),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final recordedAt = DateTime.now().toUtc();
    await LotStore.updateLot(lot.copyWith(
      quotedPrice: result['amount'] as double,
      finalSaleValue: result['amount'] as double,
      paymentStatus: 'paid',
      paymentMethod: result['method'] as String,
      transactionId: lot.transactionId ?? const Uuid().v4(),
      paymentRecordedAt: recordedAt,
    ));
    await SyncService().syncPendingLots();
    _payments = BackendService().getCollectorPayments();
    setState(() {});
  }

  Widget _lotQrButton(Lot lot) => IconButton(
        tooltip: 'Show transaction QR',
        icon: const Icon(Icons.qr_code_2),
        onPressed: () async {
          final transactionId = lot.transactionId ?? const Uuid().v4();
          final recordedAt = lot.paymentRecordedAt ?? lot.createdAt;
          final saved = lot.copyWith(
            transactionId: transactionId,
            paymentRecordedAt: recordedAt,
          );
          await LotStore.updateLot(saved);
          if (!mounted) return;
          TransactionQrButton.show(
            context,
            _lotPayload(saved, transactionId, recordedAt),
          );
        },
      );

  Map<String, dynamic> _lotPayload(Lot lot, String transactionId, DateTime at) {
    final collector = CollectorStore.getOrCreate();
    return {
      'schema': 'kabadiwala.transaction.v1',
      'transactionId': transactionId,
      'lotId': lot.id,
      'transactionStatus': 'completed',
      'collector': {
        'id': collector.collectorId,
        'name': collector.name,
        'phone': collector.phoneNumber,
        'location': collector.operatingLocation,
      },
      'recycler': lot.recyclerSnapshot ?? {'recycler_id': lot.recyclerId},
      'material': {
        'category': lot.category,
        'subCategory': lot.subCategory,
        'weightKg': lot.approxWeightKg,
        'photoReferences': lot.photoPaths,
      },
      'values': {
        'currency': 'INR',
        'estimated': lot.estimatedValue,
        'quoted': lot.quotedPrice,
        'finalSale': lot.finalSaleValue,
      },
      'payment': {
        'status': lot.paymentStatus,
        'method': lot.paymentMethod ?? 'cash',
        'recordedAt': at.toUtc().toIso8601String(),
      },
      'collection': {
        'createdAt': lot.createdAt.toUtc().toIso8601String(),
        'latitude': lot.latitude,
        'longitude': lot.longitude,
      },
    };
  }

  Map<String, dynamic> _serverTransactionPayload(Map<String, dynamic> entry) {
    final lotId = (entry['lotId'] ?? entry['lot_id'] ?? '').toString();
    final lot = _findLot(lotId);
    final id = (entry['transactionId'] ??
            entry['transaction_id'] ??
            entry['id'] ??
            'transaction-$lotId')
        .toString();
    return {
      if (lot != null)
        ..._lotPayload(lot, id, lot.paymentRecordedAt ?? lot.createdAt),
      'schema': 'kabadiwala.transaction.v1',
      'transactionId': id,
      'lotId': lotId,
      'transactionStatus': entry['transactionStatus'] ??
          entry['transaction_status'] ??
          'recorded',
      'paymentStatus':
          entry['paymentStatus'] ?? entry['payment_status'] ?? 'pending',
      'quotedPrice': entry['quotedPrice'] ?? entry['quoted_price'],
      'finalPrice': entry['finalPrice'] ?? entry['final_price'],
    };
  }

  Map<String, dynamic> _paymentPayload(Map<String, dynamic> record) {
    final lotId = (record['lotId'] ?? record['lot_id'] ?? '').toString();
    final lot = _findLot(lotId);
    final id = (record['id'] ??
            record['transactionId'] ??
            record['transaction_id'] ??
            'payment-$lotId')
        .toString();
    final at = DateTime.tryParse(
            (record['recordedAt'] ?? record['recorded_at'] ?? '').toString()) ??
        DateTime.now().toUtc();
    return {
      if (lot != null) ..._lotPayload(lot, id, at),
      'schema': 'kabadiwala.transaction.v1',
      'transactionId': id,
      'lotId': lotId,
      'payment': {
        'status': record['status'] ?? 'paid',
        'method': record['method'] ?? 'cash',
        'amount': record['amount'],
        'recordedAt': at.toUtc().toIso8601String(),
      },
      'collectorId': record['collectorId'] ?? record['collector_id'],
      'recyclerId': record['recyclerId'] ?? record['recycler_id'],
    };
  }

  Lot? _findLot(String id) {
    for (final lot in LotStore.getAllLots()) {
      if (lot.id == id) return lot;
    }
    return null;
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;
}
