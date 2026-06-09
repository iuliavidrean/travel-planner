import 'route_segment_model.dart';

class ScheduleDayRouteModel {
  final String day;
  final List<RouteSegmentModel> segments;

  ScheduleDayRouteModel({required this.day, required this.segments});

  factory ScheduleDayRouteModel.fromJson(Map<String, dynamic> json) {
    final rawSegments = (json['segments'] as List<dynamic>? ?? []);

    return ScheduleDayRouteModel(
      day: (json['day'] as String?) ?? '',
      segments: rawSegments
          .map(
            (item) => RouteSegmentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
