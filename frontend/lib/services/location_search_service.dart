import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_search_result_model.dart';

class LocationSearchService {
  static Future<List<LocationSearchResultModel>> searchLocations(
    String query,
  ) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      return [];
    }

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeQueryComponent(trimmed)}&limit=5',
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'TravelPlannerLicenta/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to search location.');
    }

    final data = jsonDecode(response.body) as List;

    return data
        .map(
          (item) =>
              LocationSearchResultModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  
  // reverse Geocoding
  static Future<String?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'TravelPlannerLicenta/1.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reverse geocode location.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['display_name']?.toString();
  }
}
