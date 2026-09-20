/// Collector — minimal profile matching SIH26229 compliance guidelines.
class CollectorProfile {
  String collectorId;
  String phoneNumber;
  String name;
  int? age;
  String preferredLanguage;
  String operatingLocation;
  List<String> transactionHistoryIds;
  double totalEarnings;
  bool hasOwnLogistics;
  double? latitude;
  double? longitude;
  bool isOnboarded;

  CollectorProfile({
    required this.collectorId,
    required this.phoneNumber,
    this.name = '',
    this.age,
    this.preferredLanguage = 'hi',
    this.operatingLocation = '',
    List<String>? transactionHistoryIds,
    this.totalEarnings = 0.0,
    this.hasOwnLogistics = false,
    this.latitude,
    this.longitude,
    this.isOnboarded = false,
  }) : transactionHistoryIds = transactionHistoryIds ?? [];

  Map<String, dynamic> toJson() => {
        'collector_id': collectorId,
        'phone_number': phoneNumber,
        'name': name,
        'age': age,
        'preferred_language': preferredLanguage,
        'operating_location': operatingLocation,
        'transaction_history_ids': transactionHistoryIds,
        'total_earnings': totalEarnings,
        'has_own_logistics': hasOwnLogistics,
        'latitude': latitude,
        'longitude': longitude,
        'is_onboarded': isOnboarded,
      };

  factory CollectorProfile.fromJson(Map<String, dynamic> json) =>
      CollectorProfile(
        collectorId:
            (json['collector_id'] ?? json['collectorId'] ?? '').toString(),
        phoneNumber:
            (json['phone_number'] ?? json['phoneNumber'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        age: json['age'] as int?,
        preferredLanguage:
            (json['preferred_language'] ?? json['preferredLanguage'] ?? 'hi')
                .toString(),
        operatingLocation:
            (json['operating_location'] ?? json['operatingLocation'] ?? '')
                .toString(),
        transactionHistoryIds: List<String>.from(
            json['transaction_history_ids'] ??
                json['transactionHistoryIds'] ??
                const []),
        totalEarnings:
            ((json['total_earnings'] ?? json['totalEarnings'] ?? 0.0) as num)
                .toDouble(),
        hasOwnLogistics: (json['has_own_logistics'] ??
            json['hasOwnLogistics'] ??
            false) as bool,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isOnboarded:
            (json['is_onboarded'] ?? json['isOnboarded'] ?? false) as bool,
      );
}
