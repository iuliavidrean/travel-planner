import 'package:flutter/material.dart';

import '../models/schedule_day_route_model.dart';
import '../models/route_segment_model.dart';
import '../models/route_info_model.dart';

// Panel rutare pe zi
class DayRoutePanel extends StatefulWidget {
  final int tripId;
  final String day;

  final bool isOutdated;
  final VoidCallback? onRecalculated;

  final Future<ScheduleDayRouteModel> Function(String day, String mode)
  loadRouteFromParent;

  const DayRoutePanel({
    super.key,
    required this.tripId,
    required this.day,
    this.isOutdated = false,
    this.onRecalculated,
    required this.loadRouteFromParent,
  });

  @override
  State<DayRoutePanel> createState() => _DayRoutePanelState();
}

class _DayRoutePanelState extends State<DayRoutePanel> {
  bool isExpanded = false;
  bool isLoading = false;
  String? errorMessage;

  String selectedMode = 'WALKING';
  ScheduleDayRouteModel? routeData;

  Future<void> loadRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await widget.loadRouteFromParent(widget.day, selectedMode);

      if (!mounted) return;

      setState(() {
        routeData = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load route for this day.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleRecalculate() async {
    await loadRoute();

    if (!mounted) return;

    widget.onRecalculated?.call();
  }

  Future<void> toggleExpanded() async {
    final nextValue = !isExpanded;

    setState(() {
      isExpanded = nextValue;
    });

    if (!nextValue) return;

    final shouldLoad = routeData == null || widget.isOutdated;

    if (shouldLoad) {
      await loadRoute();
    }
  }

  Future<void> changeMode(String mode) async {
    if (selectedMode == mode) return;

    setState(() {
      selectedMode = mode;
    });

    if (isExpanded) {
      await loadRoute();
    }
  }

  RouteInfoModel? getSegmentInfo(RouteSegmentModel segment) {
    if (selectedMode == 'WALKING') {
      return segment.walking;
    }
    return segment.driving;
  }

  double get totalDistanceKm {
    if (routeData == null) return 0.0;

    return routeData!.segments.fold(0.0, (sum, segment) {
      final info = getSegmentInfo(segment);
      return sum + (info?.distanceKm ?? 0.0);
    });
  }

  int get totalDurationMinutes {
    if (routeData == null) return 0;

    return routeData!.segments.fold(0, (sum, segment) {
      final info = getSegmentInfo(segment);
      return sum + (info?.durationMinutes ?? 0);
    });
  }

  bool get hasAnyFallback {
    if (routeData == null) return false;

    return routeData!.segments.any((segment) {
      final info = getSegmentInfo(segment);
      return info?.fallbackUsed == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF2F2F2F);
    const secondaryText = Color(0xFF6F6F6F);
    const borderColor = Color(0xFFE8ECE7);
    const softBackground = Color(0xFFF9FAF8);
    const mintSoft = Color(0xFFDDF5EF);

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: softBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // panel
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: mintSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: darkText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Route for this day',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: darkText,
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded) ...[
              const SizedBox(height: 14),

              // toggle pentru walking / driving
              Row(
                children: [
                  _RouteModeButton(
                    label: 'Walking',
                    selected: selectedMode == 'WALKING',
                    onTap: () {
                      changeMode('WALKING');
                    },
                  ),
                  const SizedBox(width: 8),
                  _RouteModeButton(
                    label: 'Driving',
                    selected: selectedMode == 'DRIVING',
                    onTap: () {
                      changeMode('DRIVING');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (widget.isOutdated) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1D9A7)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 640;

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Route needs recalculation after itinerary changes.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5C4A1D),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: isLoading ? null : handleRecalculate,
                                child: const Text('Recalculate route'),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Route needs recalculation after itinerary changes.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5C4A1D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: isLoading ? null : handleRecalculate,
                            child: const Text('Recalculate route'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (widget.isOutdated)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please recalculate the route to see the updated distances and times.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                )
              else if (routeData == null || routeData!.segments.isEmpty)
                Text(
                  'No route available for this day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            'Total: ${totalDistanceKm.toStringAsFixed(1)} km · $totalDurationMinutes min',
                            style: const TextStyle(
                              color: darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasAnyFallback)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4DD),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Approximate route',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    ...routeData!.segments.map((segment) {
                      final info = getSegmentInfo(segment);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${segment.fromTitle} → ${segment.toTitle}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: darkText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${info?.durationMinutes ?? 0} min · ${(info?.distanceKm ?? 0.0).toStringAsFixed(1)} km',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryText,
                              ),
                            ),
                            if (info?.fallbackUsed == true) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4DD),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Estimated segment',
                                  style: TextStyle(
                                    color: darkText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RouteModeButton({
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
