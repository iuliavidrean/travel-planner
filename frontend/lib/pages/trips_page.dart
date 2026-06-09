import 'package:flutter/material.dart';

import '../models/trip_model.dart';

import '../services/trip_service.dart';
import '../services/session_service.dart';

import 'home_page.dart';
import 'create_trip_page.dart';
import 'trip_details_page.dart';
import 'edit_trip_page.dart';
import 'trip_planning_mode_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<TripModel> allTrips = [];

  List<TripModel> filteredTrips = [];

  final searchController = TextEditingController();

  bool isLoading = true;

  // mesaj eroare
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTrips();
    searchController.addListener(applySearch);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // incarcare trip-uri
  Future<void> loadTrips() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final trips = await TripService.getTrips();

      if (!mounted) return;

      setState(() {
        allTrips = trips;
        filteredTrips = trips;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to load trips.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // filtru search
  void applySearch() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        filteredTrips = allTrips;
      } else {
        filteredTrips = allTrips.where((trip) {
          final city = trip.city.toLowerCase();
          final country = trip.country.toLowerCase();
          return city.contains(query) || country.contains(query);
        }).toList();
      }
    });
  }

  // logout
  Future<void> handleLogout() async {
    await SessionService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  // creare trip
  Future<void> handleCreateTrip() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateTripPage()));

    if (!mounted) return;

    if (result is TripModel) {
      await loadTrips();

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripPlanningModePage(
            tripId: result.id,
            city: result.city,
            country: result.country,
            accommodationAddress: result.accommodationAddress,
            accommodationLat: result.accommodationLat,
            accommodationLng: result.accommodationLng,
          ),
        ),
      );
      return;
    }

    if (result == true) {
      await loadTrips();
    }
  }

  Future<void> handleDeleteTrip(TripModel trip) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete trip'),
          content: Text(
            'Are you sure you want to delete the trip to ${trip.city}, ${trip.country}?',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await TripService.deleteTrip(trip.id);

      if (!mounted) return;

      await loadTrips();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to delete trip.';
      });
    }
  }

  Future<void> handleEditTrip(TripModel trip) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditTripPage(trip: trip)));

    if (result == true) {
      await loadTrips();
    }
  }

  // label mai frumos
  String formatEnumLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  // culoare pt ritm
  Color getPaceColor(String? pace) {
    switch ((pace ?? '').toLowerCase()) {
      case 'relaxed':
        return const Color(0xFFBFE7DA);
      case 'balanced':
        return const Color(0xFFD9E4F7);
      case 'packed':
        return const Color(0xFFF8DEC2);
      default:
        return const Color(0xFFE9E6E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFFDDF5EF);
    const darkText = Color(0xFF2E2A27);

    final theme = Theme.of(context);
    final isMobileScreen = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Trips'),
        actions: [
          // buton logout
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
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobileScreen ? 16 : 20,
                isMobileScreen ? 8 : 16,
                isMobileScreen ? 16 : 20,
                20,
              ),
              child: Column(
                children: [
                  // header pagina
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 760;

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Curate your next escape',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your trips, plans, and ideas — all in one elegant place.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),

                            // bara de search
                            TextField(
                              controller: searchController,
                              decoration: const InputDecoration(
                                labelText: 'Search by city or country',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // buton create
                            SizedBox(
                              height: 46,
                              child: FilledButton(
                                onPressed: handleCreateTrip,
                                child: const Text('Create Trip'),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Curate your next escape',
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(fontSize: 42),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Your trips, plans, and ideas — all in one elegant place.',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // buton create
                              SizedBox(
                                width: 220,
                                height: 54,
                                child: FilledButton(
                                  onPressed: handleCreateTrip,
                                  child: const Text('Create Trip'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // search
                          TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search by city or country',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: isMobileScreen ? 14 : 22),

                  // continut
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        // loading
                        if (isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // eroare
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

                        // empty state
                        if (filteredTrips.isEmpty) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: mintSoft,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.luggage_outlined,
                                          size: 34,
                                          color: darkText,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        "You don't have any trips planned yet.",
                                        style: theme.textTheme.headlineSmall,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Create your first trip and start building something beautiful.',
                                        style: theme.textTheme.bodyLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        onPressed: handleCreateTrip,
                                        child: const Text('Create Trip'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        // grid trip-uri
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 760;

                            if (isMobile) {
                              return ListView.separated(
                                itemCount: filteredTrips.length,
                                padding: const EdgeInsets.only(bottom: 12),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 18),
                                itemBuilder: (context, index) {
                                  final trip = filteredTrips[index];

                                  return _TripCard(
                                    trip: trip,
                                    onOpen: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TripDetailsPage(tripId: trip.id),
                                        ),
                                      );
                                    },
                                    onEdit: () {
                                      handleEditTrip(trip);
                                    },
                                    onDelete: () {
                                      handleDeleteTrip(trip);
                                    },
                                    formatEnumLabel: formatEnumLabel,
                                    getPaceColor: getPaceColor,
                                  );
                                },
                              );
                            }

                            int crossAxisCount = 2;
                            if (constraints.maxWidth >= 1180) {
                              crossAxisCount = 3;
                            }

                            return GridView.builder(
                              itemCount: filteredTrips.length,
                              padding: const EdgeInsets.only(bottom: 12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 18,
                                    mainAxisSpacing: 18,
                                    mainAxisExtent: 410,
                                  ),
                              itemBuilder: (context, index) {
                                final trip = filteredTrips[index];

                                return _TripCard(
                                  trip: trip,
                                  onOpen: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TripDetailsPage(tripId: trip.id),
                                      ),
                                    );
                                  },
                                  onEdit: () {
                                    handleEditTrip(trip);
                                  },
                                  onDelete: () {
                                    handleDeleteTrip(trip);
                                  },
                                  formatEnumLabel: formatEnumLabel,
                                  getPaceColor: getPaceColor,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// card trip
class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String value) formatEnumLabel;
  final Color Function(String? pace) getPaceColor;

  const _TripCard({
    required this.trip,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.formatEnumLabel,
    required this.getPaceColor,
  });

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFFDDF5EF);
    const darkText = Color(0xFF2E2A27);
    const secondaryText = Color(0xFF746E67);
    const borderColor = Color(0xFFE9E6E1);

    final theme = Theme.of(context);

    final paceColor = getPaceColor(trip.travelPace);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mintSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 22,
                    color: darkText,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // oras
                      Text(
                        trip.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // tara
                      Text(
                        trip.country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // badge ritm
                if (trip.travelPace != null && trip.travelPace!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: paceColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      formatEnumLabel(trip.travelPace!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: darkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // date travel
            Text(
              'Travel dates',
              style: theme.textTheme.labelMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${trip.startDate} - ${trip.endDate}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: darkText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // cazare
            Text(
              'Accommodation',
              style: theme.textTheme.labelMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              (trip.accommodationAddress == null ||
                      trip.accommodationAddress!.trim().isEmpty)
                  ? 'No accommodation added'
                  : trip.accommodationAddress!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: darkText,
                height: 1.28,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // preferinte
            Text(
              'Preferences',
              style: theme.textTheme.labelMedium?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 8),

            if (trip.preferences.isEmpty)
              Text(
                'No preferences selected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondaryText,
                  fontSize: 13,
                ),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: trip.preferences.take(3).map((preference) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: mintSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      formatEnumLabel(preference),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: darkText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 18),

            // butoane card
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 420;

                if (isMobile) {
                  final buttonTextStyle = theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            textStyle: buttonTextStyle,
                          ),
                          child: const Text('Open Trip'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: onEdit,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  textStyle: buttonTextStyle,
                                ),
                                child: const Text('Edit'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: onDelete,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  textStyle: buttonTextStyle,
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                final buttonTextStyle = theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                );

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          textStyle: buttonTextStyle,
                        ),
                        child: const Text('Open Trip'),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          textStyle: buttonTextStyle,
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          textStyle: buttonTextStyle,
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
