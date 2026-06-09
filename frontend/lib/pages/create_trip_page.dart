import 'package:flutter/material.dart';

import '../models/location_search_result_model.dart';
import 'pick_location_page.dart';

// Services
import '../services/trip_service.dart';
import '../services/session_service.dart';
import '../services/location_search_service.dart';

// Pages
import 'home_page.dart';

class CreateTripPage extends StatefulWidget {
  const CreateTripPage({super.key});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final cityController = TextEditingController();
  final countryController = TextEditingController();
  final accommodationController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  String travelPace = 'BALANCED';

  double? selectedAccommodationLat;
  double? selectedAccommodationLng;

  final Set<String> selectedPreferences = {};

  final List<String> availablePreferences = const [
    'MUSEUMS',
    'ARCHITECTURE',
    'HISTORY',
    'FOOD',
    'NATURE',
    'HIKING',
    'BEACH',
    'NIGHTLIFE',
    'MUSIC',
    'SHOPPING',
    'KIDS_FRIENDLY',
    'SPORTS',
  ];

  String? errorMessage;
  bool isLoading = false;

  bool isUpdatingAccommodationText = false;

  @override
  void initState() {
    super.initState();

    accommodationController.addListener(handleAccommodationTextChanged);
  }

  @override
  void dispose() {
    cityController.dispose();
    countryController.dispose();
    accommodationController.dispose();
    super.dispose();
  }

  Future<void> handleLogout() async {
    await SessionService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void handleAccommodationTextChanged() {
    if (isUpdatingAccommodationText) return;

    if (selectedAccommodationLat != null || selectedAccommodationLng != null) {
      setState(() {
        selectedAccommodationLat = null;
        selectedAccommodationLng = null;
      });
    }
  }

  void setAccommodationText(String value) {
    isUpdatingAccommodationText = true;
    accommodationController.text = value;
    isUpdatingAccommodationText = false;
  }

  String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String formatPreferenceLabel(String value) {
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

  Future<void> handleSearchAccommodation() async {
    final query = accommodationController.text.trim();

    if (query.isEmpty) {
      setState(() {
        errorMessage = 'Please enter an accommodation address.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await LocationSearchService.searchLocations(query);

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          errorMessage = 'No matching accommodation locations were found.';
        });
        return;
      }

      final selected = await showDialog<LocationSearchResultModel>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select accommodation'),
            content: SizedBox(
              width: 520,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = results[index];

                  return ListTile(
                    title: Text(
                      item.displayName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).pop(item);
                    },
                  );
                },
              ),
            ),
          );
        },
      );

      if (selected != null) {
        setState(() {
          setAccommodationText(selected.displayName);
          selectedAccommodationLat = selected.lat;
          selectedAccommodationLng = selected.lng;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to search accommodation.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handlePickAccommodationOnMap() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickLocationPage(
          initialLat: selectedAccommodationLat,
          initialLng: selectedAccommodationLng,
          initialCity: cityController.text.trim(),
          initialCountry: countryController.text.trim(),
        ),
      ),
    );

    if (result is Map<String, dynamic>) {
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;

      setState(() {
        selectedAccommodationLat = lat;
        selectedAccommodationLng = lng;
        errorMessage = null;
      });

      if (lat != null && lng != null) {
        try {
          final displayName = await LocationSearchService.reverseGeocode(
            lat: lat,
            lng: lng,
          );

          if (!mounted) return;

          if (displayName != null && displayName.trim().isNotEmpty) {
            setState(() {
              setAccommodationText(displayName);
            });
          }
        } catch (_) {}
      }
    }
  }

  void handleClearAccommodationLocation() {
    setState(() {
      selectedAccommodationLat = null;
      selectedAccommodationLng = null;
      accommodationController.clear();
    });
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;

        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
        }
      });
    }
  }

  Future<void> pickEndDate() async {
    final firstAllowedDate = startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? firstAllowedDate,
      firstDate: firstAllowedDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  void togglePreference(String value, bool selected) {
    setState(() {
      if (selected) {
        selectedPreferences.add(value);
      } else {
        selectedPreferences.remove(value);
      }
    });
  }

  Future<void> handleCreateTrip() async {
    setState(() {
      errorMessage = null;
    });

    final city = cityController.text.trim();
    final country = countryController.text.trim();
    final accommodationAddress = accommodationController.text.trim();

    if (city.isEmpty) {
      setState(() {
        errorMessage = 'Please enter the city.';
      });
      return;
    }

    if (country.isEmpty) {
      setState(() {
        errorMessage = 'Please enter the country.';
      });
      return;
    }

    if (startDate == null) {
      setState(() {
        errorMessage = 'Please select the start date.';
      });
      return;
    }

    if (endDate == null) {
      setState(() {
        errorMessage = 'Please select the end date.';
      });
      return;
    }

    if (startDate!.isAfter(endDate!)) {
      setState(() {
        errorMessage = 'Start date cannot be after end date.';
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final createdTrip = await TripService.createTrip(
        city: city,
        country: country,
        startDate: formatDate(startDate!),
        endDate: formatDate(endDate!),
        travelPace: travelPace,
        accommodationAddress: accommodationAddress.isEmpty
            ? null
            : accommodationAddress,
        accommodationLat: selectedAccommodationLat,
        accommodationLng: selectedAccommodationLng,
        preferences: selectedPreferences.toList(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(createdTrip);
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        errorMessage = message;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Color getPaceColor(String pace) {
    switch (pace) {
      case 'RELAXED':
        return const Color(0xFF77CDBB);
      case 'BALANCED':
        return const Color(0xFF8FB7FF);
      case 'PACKED':
        return const Color(0xFFFFBE7A);
      default:
        return const Color(0xFFE9E6E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFFDDF5EF);
    const darkText = Color(0xFF2E2A27);
    const softBackground = Color(0xFFF7F6F2);
    const borderColor = Color(0xFFE9E6E1);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trip'),
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
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: mintSoft,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 34,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // titlu pagina
                        Text(
                          'Create a new trip',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // subtitlu
                        Text(
                          'Shape your next journey with a calm, elegant planner.',
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // formular principal
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 700;

                            if (isWide) {
                              return Column(
                                children: [
                                  // rand oras tara
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: cityController,
                                          decoration: const InputDecoration(
                                            labelText: 'City',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextField(
                                          controller: countryController,
                                          decoration: const InputDecoration(
                                            labelText: 'Country',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // camp cazare
                                  TextField(
                                    controller: accommodationController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Accommodation address (optional)',
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // buton cautare cazare
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: isLoading
                                          ? null
                                          : handleSearchAccommodation,
                                      child: const Text('Search accommodation'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // card harta cazare
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: softBackground,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // titlu sectiune harta
                                        Text(
                                          'Accommodation on map (optional)',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(color: darkText),
                                        ),
                                        const SizedBox(height: 10),

                                        // coordonate selectate
                                        Text(
                                          selectedAccommodationLat != null &&
                                                  selectedAccommodationLng !=
                                                      null
                                              ? 'Lat: ${selectedAccommodationLat!.toStringAsFixed(6)} | Lng: ${selectedAccommodationLng!.toStringAsFixed(6)}'
                                              : 'No accommodation location selected yet.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: darkText),
                                        ),
                                        const SizedBox(height: 14),

                                        // butoane harta
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed:
                                                    handlePickAccommodationOnMap,
                                                child: const Text(
                                                  'Pick on Map',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed:
                                                    handleClearAccommodationLocation,
                                                child: const Text(
                                                  'Clear Location',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // rand date
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: pickStartDate,
                                          child: Text(
                                            startDate == null
                                                ? 'Select Start Date'
                                                : formatDate(startDate!),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: pickEndDate,
                                          child: Text(
                                            endDate == null
                                                ? 'Select End Date'
                                                : formatDate(endDate!),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                // camp oras
                                TextField(
                                  controller: cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'City',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // camp tara
                                TextField(
                                  controller: countryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Country',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // camp cazare
                                TextField(
                                  controller: accommodationController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Accommodation address (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // buton cautare cazare
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: isLoading
                                        ? null
                                        : handleSearchAccommodation,
                                    child: const Text('Search accommodation'),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // card harta cazare
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: softBackground,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // titlu sectiune harta
                                      Text(
                                        'Accommodation on map (optional)',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(color: darkText),
                                      ),
                                      const SizedBox(height: 10),

                                      // coordonate selectate
                                      Text(
                                        selectedAccommodationLat != null &&
                                                selectedAccommodationLng != null
                                            ? 'Lat: ${selectedAccommodationLat!.toStringAsFixed(6)} | Lng: ${selectedAccommodationLng!.toStringAsFixed(6)}'
                                            : 'No accommodation location selected yet.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: darkText),
                                      ),
                                      const SizedBox(height: 14),

                                      // buton pick map
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed:
                                              handlePickAccommodationOnMap,
                                          child: const Text('Pick on Map'),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // buton clear
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed:
                                              handleClearAccommodationLocation,
                                          child: const Text('Clear Location'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // buton start date
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: pickStartDate,
                                    child: Text(
                                      startDate == null
                                          ? 'Select Start Date'
                                          : formatDate(startDate!),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // buton end date
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: pickEndDate,
                                    child: Text(
                                      endDate == null
                                          ? 'Select End Date'
                                          : formatDate(endDate!),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // dropdown cu ritmul calatoriei
                        DropdownButtonFormField<String>(
                          initialValue: travelPace,
                          decoration: const InputDecoration(
                            labelText: 'Travel pace',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'RELAXED',
                              child: Text('Relaxed'),
                            ),
                            DropdownMenuItem(
                              value: 'BALANCED',
                              child: Text('Balanced'),
                            ),
                            DropdownMenuItem(
                              value: 'PACKED',
                              child: Text('Packed'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                travelPace = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        // badge pace selectat
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: getPaceColor(
                                travelPace,
                              ).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatPreferenceLabel(travelPace),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: darkText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // titlu preferinte
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Preferences (optional)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: darkText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // chips preferinte
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 10.0;

                            final chipsPerRow = constraints.maxWidth >= 760
                                ? 6
                                : constraints.maxWidth >= 520
                                ? 3
                                : 2;

                            final chipWidth =
                                (constraints.maxWidth -
                                    spacing * (chipsPerRow - 1)) /
                                chipsPerRow;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: 10,
                              children: availablePreferences.map((preference) {
                                final isSelected = selectedPreferences.contains(
                                  preference,
                                );

                                return SizedBox(
                                  width: chipWidth,
                                  child: FilterChip(
                                    label: Center(
                                      child: Text(
                                        formatPreferenceLabel(preference),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      togglePreference(preference, selected);
                                    },
                                    showCheckmark: false,
                                    selectedColor: const Color(
                                      0xFF77CDBB,
                                    ).withValues(alpha: 0.20),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    labelStyle: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: darkText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // mesaj eroare
                        if (errorMessage != null) ...[
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // buton create trip
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLoading ? null : handleCreateTrip,
                            child: Text(
                              isLoading ? 'Creating...' : 'Create Trip',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
