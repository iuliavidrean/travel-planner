import 'dart:convert';
import '../config/app_config.dart';

import 'package:http/http.dart' as http;

import '../models/trip_model.dart';
import 'session_service.dart';

class TripService {
  // Backend base URL
  //static const String baseUrl = 'http://localhost:8080';

  static String get baseUrl => AppConfig.baseUrl;

  // Get la vacantele utilizatorului
  static Future<List<TripModel>> getTrips() async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips');

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
          .map((item) => TripModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to load trips.');
  }

  // Get trip dupa id
  static Future<TripModel> getTripById(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TripModel.fromJson(data);
    }

    throw Exception('Failed to load trip details.');
  }

  static Future<TripModel> createTrip({
    required String city,
    required String country,
    required String startDate,
    required String endDate,
    required String travelPace,
    String? accommodationAddress,
    double? accommodationLat,
    double? accommodationLng,
    List<String>? preferences,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'city': city,
        'country': country,
        'startDate': startDate,
        'endDate': endDate,
        'travelPace': travelPace,
        'accommodationAddress': accommodationAddress,
        'accommodationLat': accommodationLat,
        'accommodationLng': accommodationLng,
        'preferences': preferences ?? [],
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TripModel.fromJson(data);
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    throw Exception('Failed to create trip.');
  }

  static Future<void> deleteTrip(int tripId) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId');

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

    throw Exception('Failed to delete trip.');
  }

  static Future<void> updateTrip({
    required int tripId,
    required String city,
    required String country,
    required String startDate,
    required String endDate,
    required String travelPace,
    String? accommodationAddress,
    double? accommodationLat,
    double? accommodationLng,
    List<String>? preferences,
  }) async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token.');
    }

    final url = Uri.parse('$baseUrl/trips/$tripId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'city': city,
        'country': country,
        'startDate': startDate,
        'endDate': endDate,
        'travelPace': travelPace,
        'accommodationAddress': accommodationAddress,
        'accommodationLat': accommodationLat,
        'accommodationLng': accommodationLng,
        'preferences': preferences ?? [],
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    throw Exception('Failed to update trip.');
  }
}
