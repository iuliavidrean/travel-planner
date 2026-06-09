import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_search_service.dart';

class PickLocationPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialCity;
  final String? initialCountry;

  const PickLocationPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialCity,
    this.initialCountry,
  });

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final MapController mapController = MapController();

  static final LatLng fallbackCenter = LatLng(45.9432, 24.9668); // Romania

  LatLng? selectedPoint;
  LatLng mapCenter = fallbackCenter;
  bool isLoadingInitialCenter = true;

  @override
  void initState() {
    super.initState();
    loadInitialCenter();
  }

  Future<void> loadInitialCenter() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        selectedPoint = LatLng(widget.initialLat!, widget.initialLng!);
        mapCenter = selectedPoint!;
        isLoadingInitialCenter = false;
      });
      return;
    }

    final city = widget.initialCity?.trim() ?? '';
    final country = widget.initialCountry?.trim() ?? '';

    if (city.isEmpty && country.isEmpty) {
      setState(() {
        mapCenter = fallbackCenter;
        isLoadingInitialCenter = false;
      });
      return;
    }

    try {
      final results = await LocationSearchService.searchLocations(
        '$city, $country',
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        setState(() {
          mapCenter = LatLng(results.first.lat, results.first.lng);
          isLoadingInitialCenter = false;
        });
        return;
      }
    } catch (_) {
      // daca geocoding-ul nu functioneaza, folosim fallback
    }

    if (!mounted) return;

    setState(() {
      mapCenter = fallbackCenter;
      isLoadingInitialCenter = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF2F2F2F);
    const secondaryText = Color(0xFF6F6F6F);
    const mintSoft = Color(0xFFADEBB3);

    if (isLoadingInitialCenter) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: selectedPoint != null ? 14 : 12,
                    onTap: (_, point) {
                      setState(() {
                        selectedPoint = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.frontend',
                    ),
                    if (selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint!,
                            width: 44,
                            height: 44,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: darkText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedPoint == null
                        ? 'Tap on the map to place a pin.'
                        : 'Lat: ${selectedPoint!.latitude.toStringAsFixed(6)}\nLng: ${selectedPoint!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: secondaryText, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              selectedPoint = null;
                            });
                          },
                          child: const Text('Clear pin'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: mintSoft,
                            foregroundColor: darkText,
                          ),
                          onPressed: selectedPoint == null
                              ? null
                              : () {
                                  Navigator.of(context).pop({
                                    'lat': selectedPoint!.latitude,
                                    'lng': selectedPoint!.longitude,
                                  });
                                },
                          child: const Center(
                            child: Text(
                              'Use this location',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
