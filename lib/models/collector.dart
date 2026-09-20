/// Collector — profile including onboarding fields (name, age, Aadhaar).
///
/// NOTE: the data dictionary calls for keeping this minimal — name, age,
/// and Aadhaar go beyond that on purpose, per an explicit product
/// decision. Aadhaar numbers carry real legal handling requirements in
/// India (UIDAI rules on storage/sharing) — this stores it locally only;
/// if it's ever synced to a backend, it must be encrypted in transit and
/// at rest, not sent as plain text.
class CollectorProfile {
  String collectorId;
  String name;
  int? age;
  String aadharNumber;
  String preferredLanguage;
  String operatingLocation;
  String phoneNumber;
  List<String> transactionHistoryIds;
  double totalEarnings;
  bool hasOwnLogistics;
  double? latitude;
  double? longitude;

  /// True once the one-time login/onboarding form has been completed.
  bool isOnboarded;

  CollectorProfile({
    required this.collectorId,
    this.name = '',
    this.age,
    this.aadharNumber = '',
    this.preferredLanguage = 'hi',
    this.operatingLocation = '',
    this.phoneNumber = '',
    List<String>? transactionHistoryIds,
    this.totalEarnings = 0,
    this.hasOwnLogistics = false,
    this.latitude,
    this.longitude,
    this.isOnboarded = false,
  }) : transactionHistoryIds = transactionHistoryIds ?? [];

  /// Last-4-only display, e.g. "XXXX XXXX 1234". Use this everywhere in
  /// the UI instead of the raw number.
  String get maskedAadhar {
    if (aadharNumber.length != 12)
      return aadharNumber.isEmpty ? '—' : aadharNumber;
    return 'XXXX XXXX ${aadharNumber.substring(8)}';
  }

  Map<String, dynamic> toJson() => {
        'collectorId': collectorId,
        'name': name,
        'age': age,
        'aadharNumber': aadharNumber,
        'preferredLanguage': preferredLanguage,
        'operatingLocation': operatingLocation,
        'phoneNumber': phoneNumber,
        'transactionHistoryIds': transactionHistoryIds,
        'totalEarnings': totalEarnings,
        'hasOwnLogistics': hasOwnLogistics,
        'latitude': latitude,
        'longitude': longitude,
        'isOnboarded': isOnboarded,
      };

  factory CollectorProfile.fromJson(Map<String, dynamic> json) =>
      CollectorProfile(
        collectorId: json['collectorId'] as String,
        name: json['name'] as String? ?? '',
        age: json['age'] as int?,
        aadharNumber: json['aadharNumber'] as String? ?? '',
        preferredLanguage: json['preferredLanguage'] as String? ?? 'hi',
        operatingLocation: json['operatingLocation'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        transactionHistoryIds: List<String>.from(
            json['transactionHistoryIds'] as List? ?? const []),
        totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0,
        hasOwnLogistics: json['hasOwnLogistics'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isOnboarded: json['isOnboarded'] as bool? ?? false,
      );
}
