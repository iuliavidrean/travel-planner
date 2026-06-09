class TripModel {
  final int id;
  final String city;
  final String country;
  final String startDate;
  final String endDate;
  final String? accommodationAddress;
  final double? accommodationLat;
  final double? accommodationLng;
  final String? travelPace;
  final List<String> preferences;

  TripModel({
    required this.id,
    required this.city,
    required this.country,
    required this.startDate,
    required this.endDate,
    this.accommodationAddress,
    this.accommodationLat,
    this.accommodationLng,
    this.travelPace,
    required this.preferences,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'],
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      accommodationAddress: json['accommodationAddress'],
      accommodationLat: json['accommodationLat'] == null
          ? null
          : (json['accommodationLat'] as num).toDouble(),
      accommodationLng: json['accommodationLng'] == null
          ? null
          : (json['accommodationLng'] as num).toDouble(),
      travelPace: json['travelPace'],
      preferences: json['preferences'] == null
          ? []
          : List<String>.from(json['preferences']),
    );
  }
}
