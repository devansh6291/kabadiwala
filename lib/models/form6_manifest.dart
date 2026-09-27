/// One signed hand-off checkpoint (dispatch / transit / delivery), matching
/// the data dictionary's Form-6 Manifest checkpoint shape.
class Form6Checkpoint {
  /// Hash of the signer's signature (drawing or typed confirmation).
  String signatureHash;
  DateTime timestamp;
  double? latitude;
  double? longitude;
  String? photoHash;

  /// This stage's link in the chain — see CryptoService.chainHash.
  String cumulativeHash;

  Form6Checkpoint({
    required this.signatureHash,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.photoHash,
    required this.cumulativeHash,
  });

  factory Form6Checkpoint.fromJson(Map<String, dynamic> json) => Form6Checkpoint(
        signatureHash: (json['signature_hash'] ?? json['signatureHash'] ?? '').toString(),
        timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        cumulativeHash: (json['cumulative_hash'] ?? json['cumulativeHash'] ?? '').toString(),
      );
}

/// Digital Form-6 Manifest — traceability record for one pooled dispatch.
/// Field names mirror the data dictionary's Form-6 section.
class Form6Manifest {
  String manifestId; // same as the pool/transaction reference
  String senderName;
  String senderPhone;
  String? senderAuthorizationNumber;
  String materialType;
  double quantity;
  String destinationRecyclerId;

  Form6Checkpoint? checkpointDispatch;
  Form6Checkpoint? checkpointTransit;
  Form6Checkpoint? checkpointDelivery;

  /// Final chain hash — only meaningful once all three checkpoints exist.
  String? get chainHash => checkpointDelivery?.cumulativeHash;

  bool get isComplete =>
      checkpointDispatch != null &&
      checkpointTransit != null &&
      checkpointDelivery != null;

  Form6Manifest({
    required this.manifestId,
    required this.senderName,
    required this.senderPhone,
    this.senderAuthorizationNumber,
    required this.materialType,
    required this.quantity,
    required this.destinationRecyclerId,
    this.checkpointDispatch,
    this.checkpointTransit,
    this.checkpointDelivery,
  });

  factory Form6Manifest.fromJson(Map<String, dynamic> json) => Form6Manifest(
        manifestId: (json['manifest_id'] ?? json['manifestId'] ?? '').toString(),
        senderName: (json['sender_name'] ?? json['senderName'] ?? '').toString(),
        senderPhone: (json['sender_phone'] ?? json['senderPhone'] ?? '').toString(),
        materialType: (json['material_type'] ?? json['materialType'] ?? '').toString(),
        quantity: ((json['quantity'] ?? 0) as num).toDouble(),
        destinationRecyclerId: (json['destination_recycler_id'] ?? json['destinationRecyclerId'] ?? '').toString(),
        checkpointDispatch: _checkpoint(json['checkpoint_dispatch'] ?? json['checkpointDispatch']),
        checkpointTransit: _checkpoint(json['checkpoint_transit'] ?? json['checkpointTransit']),
        checkpointDelivery: _checkpoint(json['checkpoint_delivery'] ?? json['checkpointDelivery']),
      );

  static Form6Checkpoint? _checkpoint(dynamic value) => value is Map
      ? Form6Checkpoint.fromJson(Map<String, dynamic>.from(value))
      : null;
}
