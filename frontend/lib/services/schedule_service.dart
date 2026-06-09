import 'dart:convert';
import 'dart:typed_data';

import '../config/app_config.dart';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/schedule_day_route_model.dart';
import '../models/schedule_day_model.dart';

import 'session_service.dart';

class ScheduleService {
  // Backend base URL
  //static const String baseUrl = 'http://localhost:8080';

  // android
  //static const String baseUrl = 'http://10.0.2.2:8080';

  static String get baseUrl => AppConfig.baseUrl;

  // Get schedule grouped by day
  static Future<List<ScheduleDayModel>> getScheduleByDay(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule/by-day');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;

      return data
          .map(
            (item) => ScheduleDayModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Failed to load schedule.');
  }

  // generare program manual
  static Future<void> generateSchedule(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule/generate');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'clearExisting': true}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw Exception('Failed to generate schedule.');
  }

  // generare program sugerat
  static Future<void> generateAiPlan(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/plan');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'mode': 'SUGGESTED', 'clearExisting': true}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw Exception('Failed to generate AI plan.');
  }

  // Clear schedule
  static Future<void> clearSchedule(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule');

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception('Failed to clear schedule.');
  }

  // adaugare activitate
  static Future<void> addScheduleItem({
    required int tripId,
    required String day,
    required String startTime,
    required String endTime,
    required String type,
    required String title,
    double? lat,
    double? lng,
    String? locationAddress,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'type': type,
        'title': title,
        'lat': lat,
        'lng': lng,
        'locationAddress': locationAddress,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    throw Exception('Failed to add schedule item.');
  }

  // update pt avtivitate
  static Future<void> updateScheduleItem({
    required int tripId,
    required int itemId,
    required String day,
    required String startTime,
    required String endTime,
    required String type,
    required String title,
    double? lat,
    double? lng,
    String? locationAddress,
    bool clearLocation = false,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule/$itemId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'type': type,
        'title': title,
        'lat': lat,
        'lng': lng,
        'locationAddress': locationAddress,
        'clearLocation': clearLocation,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    throw Exception('Failed to update schedule item.');
  }

  // stergerea activitatii
  static Future<void> deleteScheduleItem({
    required int tripId,
    required int itemId,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule/$itemId');

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    throw Exception('Failed to delete schedule item.');
  }

  // drag and drop
  static Future<void> reorderScheduleDay({
    required int tripId,
    required String day,
    required List<int> itemIds,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/schedule/reorder');

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'day': day, 'itemIds': itemIds}),
    );

    if (response.statusCode == 200) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    throw Exception('Failed to reorder schedule.');
  }

  static Future<ScheduleDayRouteModel> getRoutePlanForDay({
    required int tripId,
    required String day,
    required String mode,
  }) async {
    final token = await SessionService.getToken();

    final uri = Uri.parse(
      '$baseUrl/trips/$tripId/route-plan/day',
    ).replace(queryParameters: {'day': day, 'mode': mode});

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ScheduleDayRouteModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception('Failed to load route plan for day.');
  }

  // Export PDF
  static Future<Uint8List> exportTripPdf(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId/export/pdf');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    throw Exception('Failed to export PDF.');
  }
}
