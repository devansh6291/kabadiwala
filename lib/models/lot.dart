/// A single collected material item/batch.
///
/// Field names and types mirror the project data dictionary exactly —
/// keep this file and the dictionary in sync if either changes.
class Lot {
  /// Unique identifier (uuid), generated on-device at creation time.
  String id;

  /// Material category, e.g. "PCB", "CRT", "Cables", "Battery", "Motor",
  /// "MixedPlastics". Set by the collector in the UI.
  String category;

  /// Optional finer classification, e.g. "Motherboard" under PCB.
  /// Set by the collector or, later, the AI classifier.
  String? subCategory;

  /// Estimated weight in kilograms, entered by the collector.
  double approxWeightKg;

  /// Local file paths before sync; becomes remote URLs after sync.
  List<String> photoPaths;

  /// Instant AI/rule-based value estimate, in ₹. Filled in by the
  /// on-device classifier (currently a manual stand-in — see
  /// lib/services/classifier_service.dart).
  double? estimatedValue;

  /// Price offered once a recycler responds. Set by the backend.
  double? quotedPrice;

  /// Actual value paid once the transaction completes. Set by the backend.
  double? finalSaleValue;

  /// Timestamp of lot creation.
  DateTime createdAt;

  /// GPS latitude/longitude at creation, captured from the device.
  double? latitude;
  double? longitude;

  /// One of: "pending", "synced", "failed". Owned by the sync layer.
  String syncStatus;

  /// ID of the recycler this lot is matched/assigned to. Set by the
  /// backend matching engine.
  String? recyclerId;

  Lot({
    required this.id,
    required this.category,
    this.subCategory,
    required this.approxWeightKg,
    required this.photoPaths,
    this.estimatedValue,
    this.quotedPrice,
    this.finalSaleValue,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.syncStatus = 'pending',
    this.recyclerId,
  });

  Lot copyWith({
    String? category,
    String? subCategory,
    double? approxWeightKg,
    List<String>? photoPaths,
    double? estimatedValue,
    double? quotedPrice,
    double? finalSaleValue,
    double? latitude,
    double? longitude,
    String? syncStatus,
    String? recyclerId,
  }) {
    return Lot(
      id: id,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      approxWeightKg: approxWeightKg ?? this.approxWeightKg,
      photoPaths: photoPaths ?? this.photoPaths,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      finalSaleValue: finalSaleValue ?? this.finalSaleValue,
      createdAt: createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncStatus: syncStatus ?? this.syncStatus,
      recyclerId: recyclerId ?? this.recyclerId,
    );
  }

  /// Local (on-device) representation used by Hive for offline storage.
  /// NOTE: this keeps `createdAt` as a native DateTime for local storage.
  /// When this data is later sent to the backend over REST, the API
  /// client layer must serialize it as an ISO-8601 string and convert
  /// field names to snake_case — see the data dictionary's naming rules.
  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'subCategory': subCategory,
        'approxWeightKg': approxWeightKg,
        'photoPaths': photoPaths,
        'estimatedValue': estimatedValue,
        'quotedPrice': quotedPrice,
        'finalSaleValue': finalSaleValue,
        'createdAt': createdAt,
        'latitude': latitude,
        'longitude': longitude,
        'syncStatus': syncStatus,
        'recyclerId': recyclerId,
      };

  factory Lot.fromJson(Map<String, dynamic> json) => Lot(
        id: json['id'] as String,
        category: json['category'] as String,
        subCategory: json['subCategory'] as String?,
        approxWeightKg: (json['approxWeightKg'] as num).toDouble(),
        photoPaths: List<String>.from(json['photoPaths'] as List? ?? const []),
        estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
        quotedPrice: (json['quotedPrice'] as num?)?.toDouble(),
        finalSaleValue: (json['finalSaleValue'] as num?)?.toDouble(),
        createdAt: json['createdAt'] as DateTime,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        syncStatus: json['syncStatus'] as String? ?? 'pending',
        recyclerId: json['recyclerId'] as String?,
      );
}