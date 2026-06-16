import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import '../services/pdf_download_service.dart';

import 'edit_schedule_item_page.dart';
import 'add_schedule_item_page.dart';
import 'trip_map_view.dart';
import 'day_route_panel.dart';

import '../models/schedule_day_model.dart';
import '../models/schedule_item_model.dart';
import '../models/schedule_day_route_model.dart';

import '../services/schedule_service.dart';
import '../services/trip_service.dart';
import '../services/session_service.dart';
import 'home_page.dart';

class TripSchedulePage extends StatefulWidget {
  final int tripId;
  final String city;
  final String country;
  final String? accommodationAddress;
  final double? accommodationLat;
  final double? accommodationLng;

  const TripSchedulePage({
    super.key,
    required this.tripId,
    required this.city,
    required this.country,
    this.accommodationAddress,
    this.accommodationLat,
    this.accommodationLng,
  });

  @override
  State<TripSchedulePage> createState() => _TripSchedulePageState();
}

class _TripSchedulePageState extends State<TripSchedulePage> {
  List<ScheduleDayModel> scheduleDays = [];

  bool isLoading = true;

  bool isActionLoading = false;

  String? errorMessage;

  String selectedView = 'planner';

  String selectedMapRouteMode = 'WALKING';

  final Set<String> outdatedRouteDays = {};

  Map<String, ScheduleDayRouteModel> mapRouteByDay = {};

  final Map<String, ScheduleDayRouteModel> routeCache = {};

  bool isMapRouteLoading = false;

  @override
  void initState() {
    super.initState();
    loadSchedule();
  }

  // Logout
  Future<void> handleLogout() async {
    await SessionService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> loadSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedDays = await ScheduleService.getScheduleByDay(widget.tripId);

      if (!mounted) return;

      setState(() {
        scheduleDays = loadedDays;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load schedule.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // Generate manual schedule button action
  Future<void> handleGenerateManual() async {
    final shouldReplace = await showReplaceScheduleDialog(
      title: 'Replace current itinerary?',
      content:
          'Are you sure you want to regenerate the skeleton schedule? Your current itinerary changes will be replaced.',
    );

    if (!shouldReplace) {
      return;
    }

    setState(() {
      isActionLoading = true;
      errorMessage = null;
    });

    try {
      await ScheduleService.generateSchedule(widget.tripId);

      if (!mounted) return;

      setState(() {
        outdatedRouteDays.clear();
      });

      await loadSchedule();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to generate manual schedule.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isActionLoading = false;
      });
    }
  }

  // Mesaj cazare si harta
  bool get hasAccommodation {
    final value = widget.accommodationAddress?.trim();
    return value != null && value.isNotEmpty;
  }

  Future<void> showAccommodationRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Accommodation required'),
          content: const Text(
            'To generate an itinerary with route logic, please add your accommodation address first.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // mesaj pop up pentru butoanele Skeleton si Generate
  Future<bool> showReplaceScheduleDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // Generare plan
  Future<void> handleGenerateAi() async {
    if (!hasAccommodation) {
      await showAccommodationRequiredDialog();
      return;
    }

    final shouldReplace = await showReplaceScheduleDialog(
      title: 'Replace current itinerary?',
      content:
          'Are you sure you want to generate a new schedule? Your current itinerary changes will be replaced.',
    );

    if (!shouldReplace) {
      return;
    }

    setState(() {
      isActionLoading = true;
      errorMessage = null;
    });

    try {
      await ScheduleService.generateAiPlan(widget.tripId);

      if (!mounted) return;

      setState(() {
        outdatedRouteDays.clear();
      });

      await loadSchedule();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to generate schedule.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isActionLoading = false;
      });
    }
  }

  // Clear schedule
  Future<void> handleClearSchedule() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear itinerary'),
          content: const Text(
            'Are you sure you want to remove the current itinerary?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    setState(() {
      isActionLoading = true;
      errorMessage = null;
    });

    try {
      await ScheduleService.clearSchedule(widget.tripId);

      if (!mounted) return;

      setState(() {
        outdatedRouteDays.clear();
      });

      await loadSchedule();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to clear schedule.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isActionLoading = false;
      });
    }
  }

  // culoare text status
  Color getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUGGESTED':
        return const Color(0xFF5B3FB3);
      case 'CONFIRMED':
        return const Color(0xFF2F6B3E);
      case 'SLOT':
        return const Color(0xFF5F5F5F);
      default:
        return const Color(0xFF2F2F2F);
    }
  }

  String formatEnumLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
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

  Color getTypeColor(String type) {
    switch (type) {
      case 'ATTRACTION':
        return const Color(0xFFADEBB3);
      case 'MEAL':
        return const Color(0xFFFFE8C7);
      case 'BREAK':
        return const Color(0xFFEDEDED);
      default:
        return const Color(0xFFEDEDED);
    }
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUGGESTED':
        return const Color(0xFFE4D7FF);
      case 'CONFIRMED':
        return const Color(0xFFE7F6EA);
      case 'SLOT':
        return const Color(0xFFEDEDED);
      default:
        return const Color(0xFFEDEDED);
    }
  }

  // icon status
  IconData getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'SUGGESTED':
        return Icons.auto_awesome_rounded;
      case 'CONFIRMED':
        return Icons.verified_rounded;
      case 'SLOT':
        return Icons.view_stream_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  // fundal card dupa status
  Color getCardBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUGGESTED':
        return const Color(0xFFFCFAFF);
      case 'CONFIRMED':
        return Colors.white;
      case 'SLOT':
        return const Color(0xFFFBFBFB);
      default:
        return Colors.white;
    }
  }

  // border card dupa status
  BorderSide getCardBorder(String status) {
    switch (status.toUpperCase()) {
      case 'SUGGESTED':
        return const BorderSide(color: Color(0xFFDCCEFF));
      case 'CONFIRMED':
        return const BorderSide(color: Color(0xFFE8ECE7));
      case 'SLOT':
        return const BorderSide(color: Color(0xFFEDEDED));
      default:
        return const BorderSide(color: Color(0xFFE8ECE7));
    }
  }

  Future<void> handleAddActivity() async {
    String initialDay;

    if (scheduleDays.isNotEmpty) {
      initialDay = scheduleDays.first.day;
    } else {
      try {
        final trip = await TripService.getTripById(widget.tripId);
        initialDay = trip.startDate;
      } catch (e) {
        if (!mounted) return;

        setState(() {
          errorMessage = 'Failed to load trip dates.';
        });

        return;
      }
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddScheduleItemPage(
          tripId: widget.tripId,
          initialDay: initialDay,
          city: widget.city,
          country: widget.country,
        ),
      ),
    );

    if (result is Map<String, dynamic> && result['success'] == true) {
      final updatedDay = result['day'] as String?;
      if (updatedDay != null && updatedDay.isNotEmpty) {
        markRouteOutdated(updatedDay);
      }
      await loadSchedule();
    }
  }

  Future<void> handleEditScheduleItem(ScheduleItemModel item) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditScheduleItemPage(
          tripId: widget.tripId,
          item: item,
          city: widget.city,
          country: widget.country,
        ),
      ),
    );

    if (result == true) {
      markRouteOutdated(item.day);
      await loadSchedule();
    }
  }

  List<ScheduleItemModel> getAllScheduleItems() {
    return scheduleDays.expand((day) => day.items).toList();
  }

  List<ScheduleItemModel> getMappedItems() {
    return getAllScheduleItems()
        .where((item) => item.lat != null && item.lng != null)
        .toList();
  }

  Future<void> handleReorderDayItems({
    required String day,
    required int oldIndex,
    required int newIndex,
  }) async {
    final dayIndex = scheduleDays.indexWhere((d) => d.day == day);
    if (dayIndex == -1) return;

    final currentDay = scheduleDays[dayIndex];
    final updatedItems = List<ScheduleItemModel>.from(currentDay.items);

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final movedItem = updatedItems.removeAt(oldIndex);
    updatedItems.insert(newIndex, movedItem);

    setState(() {
      scheduleDays[dayIndex] = ScheduleDayModel(
        day: currentDay.day,
        items: updatedItems,
      );
    });

    markRouteOutdated(day);

    try {
      await ScheduleService.reorderScheduleDay(
        tripId: widget.tripId,
        day: day,
        itemIds: updatedItems.map((item) => item.id).toList(),
      );

      if (!mounted) return;
      await loadSchedule();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to reorder activities.';
      });

      await loadSchedule();
    }
  }

  // route by day daca facem drag and drop
  void markRouteOutdated(String day) {
    setState(() {
      outdatedRouteDays.add(day);

      routeCache.remove('$day|WALKING');
      routeCache.remove('$day|DRIVING');
      mapRouteByDay.remove(day);
    });
  }

  void clearRouteOutdated(String day) {
    setState(() {
      outdatedRouteDays.remove(day);
    });
  }

  // metoda comuna pentru cache
  Future<ScheduleDayRouteModel> loadSingleRouteWithCache({
    required String day,
    required String mode,
  }) async {
    final cacheKey = '$day|$mode';

    final hasValidCache =
        routeCache.containsKey(cacheKey) && !outdatedRouteDays.contains(day);

    if (hasValidCache) {
      return routeCache[cacheKey]!;
    }

    final route = await ScheduleService.getRoutePlanForDay(
      tripId: widget.tripId,
      day: day,
      mode: mode,
    );

    routeCache[cacheKey] = route;
    return route;
  }

  // rute / polyline
  // incarca rutele pentru harta mare in functie de modul selectat
  Future<void> loadRoutesForMap({String? mode}) async {
    if (scheduleDays.isEmpty) {
      if (!mounted) return;
      setState(() {
        mapRouteByDay = {};
      });
      return;
    }

    final effectiveMode = mode ?? selectedMapRouteMode;

    setState(() {
      isMapRouteLoading = true;
    });

    final Map<String, ScheduleDayRouteModel> displayRoutes = {};
    final List<String> missingDays = [];

    for (final dayGroup in scheduleDays) {
      final day = dayGroup.day;
      final cacheKey = '$day|$effectiveMode';

      final hasValidCache =
          routeCache.containsKey(cacheKey) && !outdatedRouteDays.contains(day);

      if (hasValidCache) {
        final cached = routeCache[cacheKey]!;
        if (cached.segments.isNotEmpty) {
          displayRoutes[day] = cached;
        }
      } else {
        missingDays.add(day);
      }
    }

    for (final day in missingDays) {
      try {
        final route = await loadSingleRouteWithCache(
          day: day,
          mode: effectiveMode,
        );

        if (route.segments.isNotEmpty) {
          displayRoutes[day] = route;
        }
      } catch (_) {
        // daca o zi nu are ruta, mergem mai departe
      }
    }

    if (!mounted) return;

    setState(() {
      mapRouteByDay = displayRoutes;
      isMapRouteLoading = false;
    });
  }

  // transforma geometry in polylines
  // construieste liniile afisate pe harta din geometry
  List<List<LatLng>> getMapPolylines() {
    final polylines = <List<LatLng>>[];

    for (final route in mapRouteByDay.values) {
      for (final segment in route.segments) {
        final info = selectedMapRouteMode == 'WALKING'
            ? segment.walking
            : segment.driving;

        // NU desenam fallback-ul estimativ
        if (info == null || info.fallbackUsed || info.geometry.isEmpty) {
          continue;
        }

        final points = info.geometry
            .where((coord) => coord.length >= 2)
            .map((coord) => LatLng(coord[1], coord[0]))
            .toList();

        if (points.length >= 2) {
          polylines.add(points);
        }
      }
    }

    return polylines;
  }

  Future<void> handleMapRouteModeChange(String mode) async {
    if (selectedMapRouteMode == mode) return;

    setState(() {
      selectedMapRouteMode = mode;
    });

    await loadRoutesForMap(mode: mode);
  }

  // Export  PDF
  Future<void> handleExportPdf() async {
    try {
      final Uint8List pdfBytes = await ScheduleService.exportTripPdf(
        widget.tripId,
      );

      final fileName =
          '${widget.city.toLowerCase().replaceAll(' ', '-')}-itinerary.pdf';

      await downloadPdf(pdfBytes, fileName);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFF77CDBB);
    const darkText = Color(0xFF2F2F2F);
    const secondaryText = Color(0xFF6F6F6F);

    final isMobileScreen = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Itinerary'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: handleLogout,
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobileScreen ? 12 : 16,
          isMobileScreen ? 10 : 16,
          isMobileScreen ? 12 : 16,
          20,
        ),
        child: Column(
          children: [
            // card header itinerar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFFEDEDED)),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobileScreen ? 16 : 22),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 760;
                    final theme = Theme.of(context);

                    // toggle planner / map
                    Widget viewToggle() {
                      return Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE4E1DB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ScheduleViewButton(
                              label: 'Planner',
                              selected: selectedView == 'planner',
                              onTap: () {
                                setState(() {
                                  selectedView = 'planner';
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            _ScheduleViewButton(
                              label: 'Map',
                              selected: selectedView == 'map',
                              onTap: () async {
                                if (selectedView == 'map') return;

                                setState(() {
                                  selectedView = 'map';
                                });

                                await loadRoutesForMap();
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    // butoane actiuni
                    Widget actionButtons() {
                      if (isMobile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: FilledButton(
                                      onPressed: isActionLoading
                                          ? null
                                          : handleGenerateAi,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      child: const Text(
                                        'Generate',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: FilledButton(
                                      onPressed: isActionLoading
                                          ? null
                                          : handleGenerateManual,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      child: const Text(
                                        'Skeleton',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton(
                                      onPressed: handleAddActivity,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      child: const Text(
                                        'Add',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton(
                                      onPressed: handleExportPdf,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      child: const Text(
                                        'Export',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton(
                                      onPressed: isActionLoading
                                          ? null
                                          : handleClearSchedule,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        textStyle: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: isActionLoading
                                  ? null
                                  : handleGenerateAi,
                              child: const Text('Generate schedule'),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: isActionLoading
                                  ? null
                                  : handleGenerateManual,
                              child: const Text('Skeleton'),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: handleAddActivity,
                              child: const Text('Add Activity'),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: handleExportPdf,
                              child: const Text('Export'),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: isActionLoading
                                  ? null
                                  : handleClearSchedule,
                              child: const Text('Clear'),
                            ),
                          ),
                        ],
                      );
                    }

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // info trip + toggle view
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: mintSoft.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.event_note_rounded,
                                  size: 21,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.city,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: darkText,
                                            fontSize: 22,
                                            height: 1.0,
                                          ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      widget.country,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: secondaryText,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              viewToggle(),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // actiuni
                          actionButtons(),
                          const SizedBox(height: 10),

                          // text ajutator
                          Text(
                            'Suggestions remain editable. You can reorder, edit, delete or add activities anytime.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondaryText,
                              height: 1.25,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // rand 1
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: mintSoft.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.event_note_rounded,
                                size: 30,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(width: 18),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.city,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: darkText,
                                          fontSize: 30,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.country,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: secondaryText),
                                  ),
                                ],
                              ),
                            ),

                            // toggle view
                            viewToggle(),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // rand 2 butoane
                        actionButtons(),
                        const SizedBox(height: 12),

                        // rand 3 text
                        Text(
                          'Suggestions remain editable. You can reorder, edit, delete or add activities anytime.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // mesaj Error
            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // continut pag
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Harta
                  if (selectedView == 'map') {
                    final allItems = getAllScheduleItems();
                    final mappedItems = getMappedItems();

                    final hasAccommodationMarker =
                        widget.accommodationLat != null &&
                        widget.accommodationLng != null;

                    if (allItems.isEmpty && !hasAccommodationMarker) {
                      return Center(
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: const BorderSide(color: Color(0xFFEDEDED)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: mintSoft.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: const Icon(
                                    Icons.map_outlined,
                                    size: 36,
                                    color: darkText,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No itinerary yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: darkText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Generate a plan or add activities first.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFEDEDED)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Map route mode',
                                style: TextStyle(
                                  color: darkText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedMapRouteMode == 'WALKING'
                                    ? 'Showing walking routes on the map.'
                                    : 'Showing driving routes on the map.',
                                style: const TextStyle(
                                  color: secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _ScheduleViewButton(
                                    label: 'Walking',
                                    selected: selectedMapRouteMode == 'WALKING',
                                    onTap: () {
                                      handleMapRouteModeChange('WALKING');
                                    },
                                  ),
                                  _ScheduleViewButton(
                                    label: 'Driving',
                                    selected: selectedMapRouteMode == 'DRIVING',
                                    onTap: () {
                                      handleMapRouteModeChange('DRIVING');
                                    },
                                  ),
                                  if (isMapRouteLoading)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        TripMapView(
                          items: allItems,
                          accommodationAddress: widget.accommodationAddress,
                          accommodationLat: widget.accommodationLat,
                          accommodationLng: widget.accommodationLng,
                          routePolylines: getMapPolylines(),
                          routeMode: selectedMapRouteMode,
                        ),
                        const SizedBox(height: 20),

                        // Status de la mapview
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFEDEDED)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _MapStatItem(
                                    value: '${allItems.length}',
                                    label: 'All activities',
                                  ),
                                ),
                                Expanded(
                                  child: _MapStatItem(
                                    value: '${mappedItems.length}',
                                    label: 'Mapped',
                                  ),
                                ),
                                Expanded(
                                  child: _MapStatItem(
                                    value:
                                        '${allItems.length - mappedItems.length}',
                                    label: 'Without coords',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // daca nu avem avtivitati mapate
                        if (mappedItems.isEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEDEDED),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current activities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: darkText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...allItems.map((item) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8F6),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                color: darkText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.day,
                                            style: const TextStyle(
                                              color: secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),

                        // daca avem activitati mapate
                        if (mappedItems.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEDEDED),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mapped places',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: darkText,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...mappedItems.map((item) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8F6),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            color: darkText,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    color: darkText,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${item.day} • ${formatTime(item.startTime)}',
                                                  style: const TextStyle(
                                                    color: secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  if (scheduleDays.isEmpty) {
                    return Center(
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: const BorderSide(color: Color(0xFFEDEDED)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: mintSoft.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 36,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No itinerary yet',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: darkText,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Generate a schedule or start from a manual skeleton.',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: List.generate(scheduleDays.length, (index) {
                        final dayGroup = scheduleDays[index];

                        return Container(
                          margin: EdgeInsets.only(
                            bottom: index == scheduleDays.length - 1 ? 0 : 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7F4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE6EAE5)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // header pt zi
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dayGroup.day,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              color: darkText,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: mintSoft.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${dayGroup.items.length} items',
                                        style: const TextStyle(
                                          color: darkText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                ReorderableListView.builder(
                                  key: ValueKey('reorder-${dayGroup.day}'),
                                  shrinkWrap: true,
                                  buildDefaultDragHandles: false,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: dayGroup.items.length,
                                  onReorder: (oldIndex, newIndex) {
                                    handleReorderDayItems(
                                      day: dayGroup.day,
                                      oldIndex: oldIndex,
                                      newIndex: newIndex,
                                    );
                                  },
                                  itemBuilder: (context, itemIndex) {
                                    final item = dayGroup.items[itemIndex];

                                    return Container(
                                      key: ValueKey(item.id),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: getCardBackgroundColor(
                                          item.status,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.fromBorderSide(
                                          getCardBorder(item.status),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // handle pt drag and drop
                                            ReorderableDragStartListener(
                                              index: itemIndex,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 12,
                                                  top: 8,
                                                ),
                                                child: Icon(
                                                  Icons.drag_indicator_rounded,
                                                  color: secondaryText,
                                                ),
                                              ),
                                            ),

                                            // Time column
                                            SizedBox(
                                              width: isMobileScreen ? 54 : 96,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    formatTime(item.startTime),
                                                    style: TextStyle(
                                                      color: darkText,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: isMobileScreen
                                                          ? 15
                                                          : 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatTime(item.endTime),
                                                    style: TextStyle(
                                                      color: secondaryText,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: isMobileScreen
                                                          ? 12
                                                          : 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            Container(
                                              width: 1,
                                              height: isMobileScreen ? 58 : 72,
                                              color: const Color(0xFFE8ECE7),
                                            ),
                                            SizedBox(
                                              width: isMobileScreen ? 10 : 16,
                                            ),

                                            Expanded(
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                onTap: () {
                                                  handleEditScheduleItem(item);
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item.title,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                              color: darkText,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: [
                                                          Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal:
                                                                  isMobileScreen
                                                                  ? 8
                                                                  : 12,
                                                              vertical:
                                                                  isMobileScreen
                                                                  ? 5
                                                                  : 7,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  getTypeColor(
                                                                    item.type,
                                                                  ).withValues(
                                                                    alpha: 0.42,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              formatEnumLabel(
                                                                item
                                                                        .type
                                                                        .isEmpty
                                                                    ? 'unknown'
                                                                    : item.type,
                                                              ),
                                                              style: TextStyle(
                                                                color: darkText,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                fontSize:
                                                                    isMobileScreen
                                                                    ? 12
                                                                    : 14,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal:
                                                                  isMobileScreen
                                                                  ? 8
                                                                  : 12,
                                                              vertical:
                                                                  isMobileScreen
                                                                  ? 5
                                                                  : 7,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  getStatusColor(
                                                                    item.status,
                                                                  ).withValues(
                                                                    alpha: 0.42,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  getStatusIcon(
                                                                    item.status,
                                                                  ),
                                                                  size:
                                                                      isMobileScreen
                                                                      ? 12
                                                                      : 16,
                                                                  color: getStatusTextColor(
                                                                    item.status,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Text(
                                                                  formatEnumLabel(
                                                                    item.status,
                                                                  ),
                                                                  style: TextStyle(
                                                                    color: getStatusTextColor(
                                                                      item.status,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontSize:
                                                                        isMobileScreen
                                                                        ? 12
                                                                        : 14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),

                                // panel rutare pe zi
                                DayRoutePanel(
                                  tripId: widget.tripId,
                                  day: dayGroup.day,
                                  isOutdated: outdatedRouteDays.contains(
                                    dayGroup.day,
                                  ),
                                  loadRouteFromParent: (day, mode) {
                                    return loadSingleRouteWithCache(
                                      day: day,
                                      mode: mode,
                                    );
                                  },
                                  onRecalculated: () {
                                    clearRouteOutdated(dayGroup.day);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleViewButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScheduleViewButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF2F2F2F);
    const selectedMint = Color(0xFFC9EFE7);

    final isMobile = MediaQuery.sizeOf(context).width < 760;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 22,
          vertical: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedMint : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: darkText,
            fontSize: isMobile ? 15 : 17,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _MapStatItem extends StatelessWidget {
  final String value;
  final String label;

  const _MapStatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF2F2F2F);
    const secondaryText = Color(0xFF6F6F6F);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: secondaryText),
            ),
          ),
        ),
      ],
    );
  }
}
