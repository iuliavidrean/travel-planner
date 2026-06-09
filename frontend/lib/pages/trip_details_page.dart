import 'package:flutter/material.dart';

import '../models/trip_model.dart';

import '../services/trip_service.dart';
import '../services/session_service.dart';

import 'trip_schedule_page.dart';
import 'home_page.dart';

class TripDetailsPage extends StatefulWidget {
  final int tripId;

  const TripDetailsPage({super.key, required this.tripId});

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  TripModel? trip;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTripDetails();
  }

  Future<void> handleLogout() async {
    await SessionService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> loadTripDetails() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedTrip = await TripService.getTripById(widget.tripId);

      if (!mounted) return;

      setState(() {
        trip = loadedTrip;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load trip details.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
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

  Color _paceColor(String? pace) {
    switch ((pace ?? '').toLowerCase()) {
      case 'relaxed':
        return const Color(0xFF77CDBB);
      case 'balanced':
        return const Color(0xFF8FB7FF);
      case 'packed':
        return const Color(0xFFFFBE7A);
      default:
        return const Color(0xFFE9E6E1);
    }
  }

  Widget _infoBlock(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFFDDF5EF);
    const darkText = Color(0xFF2E2A27);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (errorMessage != null) {
                    return Center(
                      child: Text(
                        errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  if (trip == null) {
                    return Center(
                      child: Text(
                        'Trip not found.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    );
                  }

                  final tripData = trip!;
                  final paceColor = _paceColor(tripData.travelPace);

                  return SingleChildScrollView(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile = constraints.maxWidth < 720;

                                if (isMobile) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 74,
                                        height: 74,
                                        decoration: BoxDecoration(
                                          color: mintSoft,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.travel_explore_rounded,
                                          size: 36,
                                          color: darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        tripData.city,
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        tripData.country,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 14),
                                      if (tripData.travelPace != null &&
                                          tripData.travelPace!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: paceColor.withValues(
                                              alpha: 0.22,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            formatEnumLabel(
                                              tripData.travelPace!,
                                            ),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: darkText,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 74,
                                      height: 74,
                                      decoration: BoxDecoration(
                                        color: mintSoft,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.travel_explore_rounded,
                                        size: 36,
                                        color: darkText,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tripData.city,
                                            style:
                                                theme.textTheme.headlineMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            tripData.country,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (tripData.travelPace != null &&
                                        tripData.travelPace!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: paceColor.withValues(
                                            alpha: 0.22,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          formatEnumLabel(tripData.travelPace!),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: darkText,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            Divider(color: Theme.of(context).dividerColor),
                            const SizedBox(height: 24),
                            _infoBlock(
                              context,
                              label: 'Travel dates',
                              child: Text(
                                '${tripData.startDate} - ${tripData.endDate}',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: darkText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _infoBlock(
                              context,
                              label: 'Travel pace',
                              child: Text(
                                tripData.travelPace == null ||
                                        tripData.travelPace!.isEmpty
                                    ? 'Not set'
                                    : formatEnumLabel(tripData.travelPace!),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: darkText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _infoBlock(
                              context,
                              label: 'Accommodation',
                              child: Text(
                                (tripData.accommodationAddress == null ||
                                        tripData.accommodationAddress!
                                            .trim()
                                            .isEmpty)
                                    ? 'No accommodation address added.'
                                    : tripData.accommodationAddress!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: darkText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _infoBlock(
                              context,
                              label: 'Preferences',
                              child: tripData.preferences.isEmpty
                                  ? Text(
                                      'No preferences selected.',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: darkText),
                                    )
                                  : Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: tripData.preferences.map((
                                        preference,
                                      ) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: mintSoft,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE9E6E1),
                                            ),
                                          ),
                                          child: Text(
                                            formatEnumLabel(preference),
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: darkText,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TripSchedulePage(
                                        tripId: tripData.id,
                                        city: tripData.city,
                                        country: tripData.country,
                                        accommodationAddress:
                                            tripData.accommodationAddress,
                                        accommodationLat:
                                            tripData.accommodationLat,
                                        accommodationLng:
                                            tripData.accommodationLng,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('View Itinerary'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
