class LocationSearchResultModel {
  final String displayName;
  final double lat;
  final double lng;

  LocationSearchResultModel({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory LocationSearchResultModel.fromJson(Map<String, dynamic> json) {
    return LocationSearchResultModel(
      displayName: (json['display_name'] ?? 'Unknown location').toString(),
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
    );
  }
}
