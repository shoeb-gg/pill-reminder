import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import '../providers/medication_provider.dart';
import '../widgets/pill_icon.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateWeekDates();
  }

  void _generateWeekDates() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    _weekDates = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final dbService = ref.watch(databaseServiceProvider);
    final medications = ref.watch(medicationsProvider);
    final doseLogs = dbService.getDoseLogsForDate(_selectedDate);

    // Calculate stats
    final takenCount = doseLogs.where((l) => l.status == DoseStatus.taken).length;
    final missedCount = doseLogs.where((l) => l.status == DoseStatus.missed).length;
    final totalCount = doseLogs.length;
    final adherencePercent = totalCount > 0 ? (takenCount / totalCount * 100).round() : 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'History',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            // Calendar strip
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: _weekDates.map((date) {
                  final isSelected = _isSameDay(date, _selectedDate);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('E').format(date).substring(0, 1),
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatCard(
                    value: '$adherencePercent%',
                    label: 'Adherence',
                    valueColor: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: '$takenCount',
                    label: 'Taken',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: '$missedCount',
                    label: 'Missed',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Date label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                DateFormat('MMMM d').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // History list
            Expanded(
              child: doseLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No dose logs for this day',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: doseLogs.length,
                      itemBuilder: (context, index) {
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
                        return _HistoryItem(
                          medication: medication,
                          doseLog: log,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCard({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Medication medication;
  final DoseLog doseLog;

  const _HistoryItem({
    required this.medication,
    required this.doseLog,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    String statusText;
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    switch (doseLog.status) {
      case DoseStatus.taken:
        statusText = 'Taken at ${timeFormat.format(doseLog.actionTime ?? doseLog.scheduledTime)}';
        statusColor = AppColors.success;
        statusBgColor = AppColors.successLight;
        statusIcon = Icons.check;
        break;
      case DoseStatus.skipped:
        statusText = 'Skipped at ${timeFormat.format(doseLog.actionTime ?? doseLog.scheduledTime)}';
        statusColor = AppColors.warning;
        statusBgColor = AppColors.warningLight;
        statusIcon = Icons.remove;
        break;
      case DoseStatus.missed:
        statusText = 'Missed at ${timeFormat.format(doseLog.scheduledTime)}';
        statusColor = AppColors.danger;
        statusBgColor = AppColors.dangerLight;
        statusIcon = Icons.close;
        break;
      case DoseStatus.pending:
        statusText = 'Pending at ${timeFormat.format(doseLog.scheduledTime)}';
        statusColor = AppColors.textMuted;
        statusBgColor = AppColors.background;
        statusIcon = Icons.schedule;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          PillIcon(colorIndex: medication.colorIndex),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
        ],
      ),
    );
  }
}
