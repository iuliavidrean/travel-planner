class RouteInfoModel {
  final double distanceKm;
  final int durationMinutes;
  final String mode;
  final bool fallbackUsed;
  final List<List<double>> geometry;

  RouteInfoModel({
    required this.distanceKm,
    required this.durationMinutes,
    required this.mode,
    required this.fallbackUsed,
    required this.geometry,
  });

  factory RouteInfoModel.fromJson(Map<String, dynamic> json) {
    final rawGeometry = (json['geometry'] as List<dynamic>? ?? []);

    return RouteInfoModel(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      mode: (json['mode'] as String?) ?? '',
      fallbackUsed: (json['fallbackUsed'] as bool?) ?? false,
      geometry: rawGeometry.map((point) {
        final coords = point as List<dynamic>;
        return coords.map((value) => (value as num).toDouble()).toList();
      }).toList(),
    );
  }
}
