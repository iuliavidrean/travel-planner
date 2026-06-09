import 'package:flutter/material.dart';

import '../services/schedule_service.dart';
import 'pick_location_page.dart';

// pentru locatia atractiei
import '../models/location_search_result_model.dart';
import '../services/location_search_service.dart';

// Pagina add activity
class AddScheduleItemPage extends StatefulWidget {
  final int tripId;
  final String initialDay;
  final String city;
  final String country;

  const AddScheduleItemPage({
    super.key,
    required this.tripId,
    required this.initialDay,
    required this.city,
    required this.country,
  });

  @override
  State<AddScheduleItemPage> createState() => _AddScheduleItemPageState();
}

class _AddScheduleItemPageState extends State<AddScheduleItemPage> {
  final titleController = TextEditingController();
  final locationQueryController = TextEditingController();

  late DateTime selectedDay;
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
  String selectedType = 'ATTRACTION';

  double? selectedLat;
  double? selectedLng;

  bool isLoading = false;
  String? errorMessage;

  bool isUpdatingLocationText = false;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.parse(widget.initialDay);

    locationQueryController.addListener(handleLocationTextChanged);
  }

  @override
  void dispose() {
    titleController.dispose();
    locationQueryController.dispose();
    super.dispose();
  }

  void handleLocationTextChanged() {
    if (isUpdatingLocationText) return;

    if (selectedLat != null || selectedLng != null) {
      setState(() {
        selectedLat = null;
        selectedLng = null;
      });
    }
  }

  void setLocationText(String value) {
    isUpdatingLocationText = true;
    locationQueryController.text = value;
    isUpdatingLocationText = false;
  }

  String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String formatTimeForBackend(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String formatTimeForUi(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDay = picked;
      });
    }
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: endTime);

    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  Future<void> handlePickLocation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PickLocationPage(
          initialLat: selectedLat,
          initialLng: selectedLng,
          initialCity: widget.city,
          initialCountry: widget.country,
        ),
      ),
    );

    if (result is Map<String, dynamic>) {
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;

      setState(() {
        selectedLat = lat;
        selectedLng = lng;
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
              setLocationText(displayName);
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> handleSearchLocation() async {
    final query = locationQueryController.text.trim();

    if (query.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a location name or address.';
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
          errorMessage = 'No matching locations were found.';
        });
        return;
      }

      final selected = await showDialog<LocationSearchResultModel>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select location'),
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
          setLocationText(selected.displayName);
          selectedLat = selected.lat;
          selectedLng = selected.lng;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to search location.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  void handleClearLocation() {
    setState(() {
      selectedLat = null;
      selectedLng = null;
      locationQueryController.clear();
    });
  }

  Future<void> handleCreateActivity() async {
    setState(() {
      errorMessage = null;
    });

    final title = titleController.text.trim();

    if (title.isEmpty) {
      setState(() {
        errorMessage = 'Please enter an activity title.';
      });
      return;
    }

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes <= startMinutes) {
      setState(() {
        errorMessage = 'End time must be after start time.';
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ScheduleService.addScheduleItem(
        tripId: widget.tripId,
        day: formatDate(selectedDay),
        startTime: formatTimeForBackend(startTime),
        endTime: formatTimeForBackend(endTime),
        type: selectedType,
        title: title,
        lat: selectedLat,
        lng: selectedLng,
        locationAddress: locationQueryController.text.trim().isEmpty
            ? null
            : locationQueryController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pop({'success': true, 'day': formatDate(selectedDay)});
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        if (message.contains('overlaps with existing item')) {
          errorMessage =
              'This activity overlaps with another activity on the same day.';
        } else {
          errorMessage = message;
        }
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
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
      appBar: AppBar(title: const Text('Add Activity')),
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
                        // icon pagina
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: mintSoft,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.add_task_rounded,
                            size: 34,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // titlu pagina
                        Text(
                          'Add activity',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // camp titlu
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 16),

                        // camp locatie
                        TextField(
                          controller: locationQueryController,
                          decoration: const InputDecoration(
                            labelText: 'Location name or address (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // buton search locatie
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : handleSearchLocation,
                            child: const Text('Search location'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // card map locatie
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: softBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // titlu map locatie
                              Text(
                                'Location on map (optional)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // coordonate
                              Text(
                                selectedLat != null && selectedLng != null
                                    ? 'Lat: ${selectedLat!.toStringAsFixed(6)} | Lng: ${selectedLng!.toStringAsFixed(6)}'
                                    : 'No map location selected yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 14),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 620;

                                  if (isMobile) {
                                    return Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: handlePickLocation,
                                            child: const Text(
                                              'Pick location on map',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: handleClearLocation,
                                            child: const Text('Clear location'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: handlePickLocation,
                                          child: const Text(
                                            'Pick location on map',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: handleClearLocation,
                                          child: const Text('Clear location'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // zi + start + end
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 720;

                            if (isMobile) {
                              return Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: pickDay,
                                      child: Text(formatDate(selectedDay)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: pickStartTime,
                                      child: Text(formatTimeForUi(startTime)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: pickEndTime,
                                      child: Text(formatTimeForUi(endTime)),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: pickDay,
                                    child: Text(formatDate(selectedDay)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: pickStartTime,
                                    child: Text(formatTimeForUi(startTime)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: pickEndTime,
                                    child: Text(formatTimeForUi(endTime)),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // dropdown tip activitate
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Activity type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ATTRACTION',
                              child: Text('Attraction'),
                            ),
                            DropdownMenuItem(
                              value: 'MEAL',
                              child: Text('Meal'),
                            ),
                            DropdownMenuItem(
                              value: 'BREAK',
                              child: Text('Break'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedType = value;
                              });
                            }
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

                        // buton add
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLoading ? null : handleCreateActivity,
                            child: Text(
                              isLoading ? 'Creating...' : 'Add activity',
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
