import 'schedule_item_model.dart';

class ScheduleDayModel {
  final String day;
  final List<ScheduleItemModel> items;

  ScheduleDayModel({required this.day, required this.items});

  factory ScheduleDayModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ScheduleDayModel(
      day: (json['day'] ?? '').toString(),
      items: rawItems is List
          ? rawItems
                .map(
                  (item) =>
                      ScheduleItemModel.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
    );
  }
}
