import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/schedule_item_model.dart';

// Harta generala
class TripMapView extends StatefulWidget {
  final List<ScheduleItemModel> items;
  final String? accommodationAddress;
  final double? accommodationLat;
  final double? accommodationLng;

  // rute
  final List<List<LatLng>> routePolylines;

  final String routeMode;

  const TripMapView({
    super.key,
    required this.items,
    this.accommodationAddress,
    this.accommodationLat,
    this.accommodationLng,
    this.routePolylines = const [],
    this.routeMode = 'WALKING',
  });

  @override
  State<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends State<TripMapView> {
  final MapController mapController = MapController();

  static final LatLng fallbackCenter = LatLng(45.9432, 24.9668); // Romania

  List<ScheduleItemModel> get mappedItems {
    return widget.items
        .where((item) => item.lat != null && item.lng != null)
        .toList();
  }

  bool get hasAccommodationMarker {
    return widget.accommodationLat != null && widget.accommodationLng != null;
  }

  LatLng get initialCenter {
    if (mappedItems.isNotEmpty) {
      return LatLng(mappedItems.first.lat!, mappedItems.first.lng!);
    }

    if (hasAccommodationMarker) {
      return LatLng(widget.accommodationLat!, widget.accommodationLng!);
    }

    return fallbackCenter;
  }

  String formatTime(String? value) {
    if (value == null || value.isEmpty) {
      return '--:--';
    }

    final parts = value.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }

    return value;
  }

  List<Marker> buildMarkers() {
    final markers = <Marker>[];

    if (hasAccommodationMarker) {
      markers.add(
        Marker(
          point: LatLng(widget.accommodationLat!, widget.accommodationLng!),
          width: 46,
          height: 46,
          child: Tooltip(
            message: widget.accommodationAddress ?? 'Accommodation',
            child: const Icon(Icons.home_rounded, size: 40, color: Colors.blue),
          ),
        ),
      );
    }

    markers.addAll(
      mappedItems.map((item) {
        return Marker(
          point: LatLng(item.lat!, item.lng!),
          width: 44,
          height: 44,
          child: Tooltip(
            message:
                '${item.title}\n${item.day} • ${formatTime(item.startTime)}',
            child: const Icon(Icons.location_pin, size: 40, color: Colors.red),
          ),
        );
      }),
    );

    return markers;
  }

  List<Polyline> buildPolylines() {
    final routeColor = widget.routeMode == 'DRIVING'
        ? const Color(0xFF2F6B3E)
        : const Color(0xFF5B3FB3);

    return widget.routePolylines
        .where((points) => points.length >= 2)
        .map(
          (points) =>
              Polyline(points: points, strokeWidth: 4, color: routeColor),
        )
        .toList();
  }

  void fitMarkers() {
    final points = <LatLng>[];

    if (hasAccommodationMarker) {
      points.add(LatLng(widget.accommodationLat!, widget.accommodationLng!));
    }

    for (final item in mappedItems) {
      points.add(LatLng(item.lat!, item.lng!));
    }

    for (final polyline in widget.routePolylines) {
      points.addAll(polyline);
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      mapController.move(points.first, 14);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitMarkers();
    });
  }

  @override
  void didUpdateWidget(covariant TripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    const secondaryText = Color(0xFF6F6F6F);

    return Column(
      children: [
        Container(
          height: 420,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: mappedItems.isNotEmpty || hasAccommodationMarker
                  ? 13
                  : 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend',
              ),
              if (widget.routePolylines.isNotEmpty)
                PolylineLayer(polylines: buildPolylines()),
              MarkerLayer(markers: buildMarkers()),
            ],
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
          child: Text(
            mappedItems.isEmpty && !hasAccommodationMarker
                ? 'No mapped locations yet. Add or edit activities with a location to see them on the map.'
                : hasAccommodationMarker
                ? '${mappedItems.length} mapped activit${mappedItems.length == 1 ? 'y' : 'ies'} plus accommodation are currently displayed on the map. Route mode: ${widget.routeMode == 'WALKING' ? 'Walking' : 'Driving'}.'
                : '${mappedItems.length} mapped activit${mappedItems.length == 1 ? 'y is' : 'ies are'} currently displayed on the map. Route mode: ${widget.routeMode == 'WALKING' ? 'Walking' : 'Driving'}.',
            style: const TextStyle(color: secondaryText, height: 1.5),
          ),
        ),
      ],
    );
  }
}
