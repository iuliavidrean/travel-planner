import 'package:flutter/material.dart';
import 'trip_schedule_page.dart';
import '../services/schedule_service.dart';
import '../services/session_service.dart';
import 'home_page.dart';

// Pagina alegere mod planificare
class TripPlanningModePage extends StatelessWidget {
  final int tripId;
  final String city;
  final String country;
  final String? accommodationAddress;
  final double? accommodationLat;
  final double? accommodationLng;

  const TripPlanningModePage({
    super.key,
    required this.tripId,
    required this.city,
    required this.country,
    this.accommodationAddress,
    this.accommodationLat,
    this.accommodationLng,
  });

  // logout
  Future<void> handleLogout(BuildContext context) async {
    await SessionService.clearToken();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  bool get hasAccommodation {
    final value = accommodationAddress?.trim();
    return value != null && value.isNotEmpty;
  }

  // dialog cazare lipsa
  Future<void> showAccommodationRequiredDialog(BuildContext context) async {
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

  // generare itinerar
  Future<void> handleGenerateAi(BuildContext context) async {
    if (!hasAccommodation) {
      await showAccommodationRequiredDialog(context);
      return;
    }

    try {
      await ScheduleService.generateAiPlan(tripId);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripSchedulePage(
            tripId: tripId,
            city: city,
            country: country,
            accommodationAddress: accommodationAddress,
            accommodationLat: accommodationLat,
            accommodationLng: accommodationLng,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate schedule.')),
      );
    }
  }

  // generare schelet
  Future<void> handleGenerateManual(BuildContext context) async {
    try {
      await ScheduleService.generateSchedule(tripId);

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TripSchedulePage(
            tripId: tripId,
            city: city,
            country: country,
            accommodationAddress: accommodationAddress,
            accommodationLat: accommodationLat,
            accommodationLng: accommodationLng,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate manual schedule.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const secondaryText = Color(0xFF746E67);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan your trip'),
        actions: [
          // buton logout
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () {
                handleLogout(context);
              },
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // titlu pagina
                        Text(
                          'How would you like to plan your trip?',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),

                        // subtitlu pagina
                        Text(
                          '$city, $country',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // carduri mod planificare
                        if (isMobile)
                          Column(
                            children: [
                              _PlanningModeCard(
                                icon: Icons.auto_awesome_rounded,
                                title: 'Suggested Schedule',
                                description:
                                    'Get a suggested draft itinerary based on your travel pace and preferences, then edit everything manually if needed.',
                                hints: const [
                                  'A first draft is created for you',
                                  'Accommodation is required',
                                  'You can edit everything afterwards',
                                ],
                                buttonText: 'Generate schedule',
                                isAiCard: true,
                                onPressed: () async {
                                  await handleGenerateAi(context);
                                },
                              ),
                              const SizedBox(height: 18),
                              _PlanningModeCard(
                                icon: Icons.edit_calendar_rounded,
                                title: 'Build Manually',
                                description:
                                    'Start from a simple skeleton schedule and build your itinerary step by step with full manual control.',
                                hints: const [
                                  'Starts from a flexible skeleton',
                                  'Full manual control',
                                  'Map works for activities with locations',
                                ],
                                buttonText: 'Start manual planning',
                                onPressed: () async {
                                  await handleGenerateManual(context);
                                },
                              ),
                            ],
                          )
                        else
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _PlanningModeCard(
                                    icon: Icons.auto_awesome_rounded,
                                    title: 'Suggested Schedule',
                                    description:
                                        'Get a suggested draft itinerary based on your travel pace and preferences, then edit everything manually if needed.',
                                    hints: const [
                                      'A first draft is created for you',
                                      'Accommodation is required',
                                      'You can edit everything afterwards',
                                    ],
                                    buttonText: 'Generate schedule',
                                    isAiCard: true,
                                    onPressed: () async {
                                      await handleGenerateAi(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _PlanningModeCard(
                                    icon: Icons.edit_calendar_rounded,
                                    title: 'Build Manually',
                                    description:
                                        'Start from a simple skeleton schedule and build your itinerary step by step with full manual control.',
                                    hints: const [
                                      'Starts from a flexible skeleton',
                                      'Full manual control',
                                      'Map works for activities with locations',
                                    ],
                                    buttonText: 'Start manual planning',
                                    onPressed: () async {
                                      await handleGenerateManual(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),

                        // text de jos
                        Text(
                          'Both planning modes remain editable. Your itinerary stays synchronized with the planner and map views.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

// card mod planificare
class _PlanningModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> hints;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isAiCard;

  const _PlanningModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.hints,
    required this.buttonText,
    required this.onPressed,
    this.isAiCard = false,
  });

  @override
  Widget build(BuildContext context) {
    const mintSoft = Color(0xFFDDF5EF);
    const darkText = Color(0xFF2E2A27);

    const aiSoft = Color(0xFFFCFAFF);
    const aiBorder = Color(0xFFE2D6FF);
    const aiIconBg = Color(0xFFE9DDFF);
    const aiButton = Color(0xFF8C6AE8);

    final theme = Theme.of(context);

    final cardBackground = isAiCard ? aiSoft : Colors.white;
    final cardBorder = isAiCard ? aiBorder : const Color(0xFFEDEDED);
    final iconBackground = isAiCard ? aiIconBg : mintSoft;

    return Card(
      color: cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // icon card
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 36, color: darkText),
              ),
            ),
            const SizedBox(height: 20),

            // titlu card
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: darkText,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // descriere
            Text(
              description,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // lista beneficii
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(hints.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == hints.length - 1 ? 0 : 10,
                    ),
                    child: _ModeHintRow(text: hints[index]),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // buton principal
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: isAiCard
                    ? FilledButton.styleFrom(
                        backgroundColor: aiButton,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// rand cu hint
class _ModeHintRow extends StatelessWidget {
  final String text;

  const _ModeHintRow({required this.text});

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF2F2F2F);
    const secondaryText = Color(0xFF6F6F6F);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: darkText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondaryText),
          ),
        ),
      ],
    );
  }
}
