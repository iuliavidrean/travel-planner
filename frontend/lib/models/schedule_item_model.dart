class ScheduleItemModel {
  final int id;
  final String day;
  final String? startTime;
  final String? endTime;
  final String type;
  final String title;
  final double? lat;
  final double? lng;
  final String? locationAddress;
  final int? sortOrder;
  final String status;

  ScheduleItemModel({
    required this.id,
    required this.day,
    this.startTime,
    this.endTime,
    required this.type,
    required this.title,
    this.lat,
    this.lng,
    this.locationAddress,
    this.sortOrder,
    required this.status,
  });

  factory ScheduleItemModel.fromJson(Map<String, dynamic> json) {
    return ScheduleItemModel(
      id: (json['id'] ?? 0) as int,
      day: (json['day'] ?? '').toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      type: (json['type'] ?? 'UNKNOWN').toString(),
      title: (json['title'] ?? 'Untitled activity').toString(),
      lat: json['lat'] == null ? null : (json['lat'] as num).toDouble(),
      lng: json['lng'] == null ? null : (json['lng'] as num).toDouble(),
      locationAddress: json['locationAddress']?.toString(),
      sortOrder: json['sortOrder'] as int?,
      status: (json['status'] ?? 'UNKNOWN').toString(),
    );
  }
}
