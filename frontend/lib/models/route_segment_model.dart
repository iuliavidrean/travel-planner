import 'route_info_model.dart';

class RouteSegmentModel {
  final String fromTitle;
  final double? fromLat;
  final double? fromLng;
  final String toTitle;
  final double? toLat;
  final double? toLng;
  final RouteInfoModel? walking;
  final RouteInfoModel? driving;

  RouteSegmentModel({
    required this.fromTitle,
    required this.fromLat,
    required this.fromLng,
    required this.toTitle,
    required this.toLat,
    required this.toLng,
    required this.walking,
    required this.driving,
  });

  factory RouteSegmentModel.fromJson(Map<String, dynamic> json) {
    return RouteSegmentModel(
      fromTitle: (json['fromTitle'] as String?) ?? '',
      fromLat: (json['fromLat'] as num?)?.toDouble(),
      fromLng: (json['fromLng'] as num?)?.toDouble(),
      toTitle: (json['toTitle'] as String?) ?? '',
      toLat: (json['toLat'] as num?)?.toDouble(),
      toLng: (json['toLng'] as num?)?.toDouble(),
      walking: json['walking'] != null
          ? RouteInfoModel.fromJson(json['walking'] as Map<String, dynamic>)
          : null,
      driving: json['driving'] != null
          ? RouteInfoModel.fromJson(json['driving'] as Map<String, dynamic>)
          : null,
    );
  }
}
