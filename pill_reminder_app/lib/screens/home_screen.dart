import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_card.dart';
import '../widgets/inventory_card.dart';
import 'add_edit_medication_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Delay state modification until after build
    Future.microtask(() => _generateTodaysDoses());
  }

  void _generateTodaysDoses() {
    if (!mounted) return;

    final medications = ref.read(activeMedicationsProvider);
    final dbService = ref.read(databaseServiceProvider);
    final today = DateTime.now();
    final todayWeekday = today.weekday; // 1=Mon, 2=Tue, ..., 7=Sun
    final existingLogs = dbService.getDoseLogsForDate(today);

    // Clean up stale logs for medications not scheduled today
    for (final log in existingLogs) {
      final medication = medications.firstWhere(
        (m) => m.id == log.medicationId,
        orElse: () => Medication(
          id: '',
          name: '',
          dosage: '',
          scheduledTimes: [],
          currentStock: 0,
        ),
      );
      // Delete log if medication doesn't exist or today isn't a reminder day
      if (medication.id.isEmpty ||
          medication.reminderDays.isEmpty ||
          !medication.reminderDays.contains(todayWeekday)) {
        dbService.deleteDoseLog(log.id);
      }
    }

    for (final medication in medications) {
      // Skip if today is not in reminder days (empty means no reminders)
      if (medication.reminderDays.isEmpty ||
          !medication.reminderDays.contains(todayWeekday)) {
        continue;
      }

      for (final timeStr in medication.scheduledTimes) {
        final timeParts = timeStr.split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final scheduledTime = DateTime(
          today.year,
          today.month,
          today.day,
          hour,
          minute,
        );

        // Check if log already exists for this medication and time
        final exists = existingLogs.any((log) =>
            log.medicationId == medication.id &&
            log.scheduledTime.hour == hour &&
            log.scheduledTime.minute == minute);

        if (!exists) {
          final log = DoseLog(
            id: '${medication.id}_${scheduledTime.millisecondsSinceEpoch}',
            medicationId: medication.id,
            scheduledTime: scheduledTime,
          );
          dbService.addDoseLog(log);
        }
      }
    }

    // Refresh the dose logs
    if (mounted) {
      ref.read(doseLogsProvider.notifier).loadLogsForDate(today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medications = ref.watch(activeMedicationsProvider);
    final doseLogs = ref.watch(doseLogsProvider);
    final lowStockMeds = ref.watch(lowStockMedicationsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _generateTodaysDoses();
          },
          child: CustomScrollView(
            slivers: [
              // Header with notification icon
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Reminders",
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      _NotificationButton(
                        hasNotification: lowStockMeds.isNotEmpty,
                        onTap: () => _showLowStockDialog(context, lowStockMeds),
                      ),
                    ],
                  ),
                ),
              ),

              // Medication Cards
              if (doseLogs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.medication_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            medications.isEmpty
                                ? 'No medications added yet'
                                : 'No medications scheduled for today',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          if (medications.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Add a medication to get started',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final log = doseLogs[index];
                        final medication = medications.firstWhere(
                          (m) => m.id == log.medicationId,
                          orElse: () => Medication(
                            id: '',
                            name: 'Unknown',
                            dosage: '',
                            scheduledTimes: [],
                            currentStock: 0,
                          ),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MedicationCard(
                            medication: medication,
                            doseLog: log,
                            onTake: () => _handleTakeDose(log, medication),
                            onSkip: () => _handleSkipDose(log, medication),
                            onTap: () => _navigateToEditMedication(medication),
                          ),
                        );
                      },
                      childCount: doseLogs.length,
                    ),
                  ),
                ),

              // Inventory Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Inventory',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to medications list
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'See All',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Inventory Grid
              if (medications.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No medications added yet',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final medication = medications[index];
                        return InventoryCard(
                          medication: medication,
                          onTap: () => _navigateToEditMedication(medication),
                        );
                      },
                      childCount: medications.length > 4 ? 4 : medications.length,
                    ),
                  ),
                ),

              // Bottom padding for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditMedicationScreen(),
                ),
              ).then((_) => _generateTodaysDoses());
            },
            label: const Text('+ New Reminder'),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _navigateToEditMedication(Medication medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMedicationScreen(medication: medication),
      ),
    ).then((_) => _generateTodaysDoses());
  }

  void _handleTakeDose(DoseLog log, Medication medication) {
    ref.read(doseLogsProvider.notifier).markDoseTaken(
          log,
          medication.pillsPerDose,
          medication: medication,
        );
    ref.read(medicationsProvider.notifier).decrementStock(
          medication.id,
          medication.pillsPerDose,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${medication.name} marked as taken'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _handleSkipDose(DoseLog log, Medication medication) {
    ref.read(doseLogsProvider.notifier).markDoseSkipped(log, medication: medication);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dose skipped'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, List<Medication> lowStockMeds) {
    if (lowStockMeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No low stock alerts'),
          backgroundColor: AppColors.success,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Stock Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lowStockMeds
              .map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${m.name}: ${m.currentStock} remaining'),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final bool hasNotification;
  final VoidCallback onTap;

  const _NotificationButton({
    this.hasNotification = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
            ),
            if (hasNotification)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
