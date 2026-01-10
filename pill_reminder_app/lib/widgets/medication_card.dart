import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';
import 'pill_icon.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final DoseLog doseLog;
  final VoidCallback onTake;
  final VoidCallback onSkip;
  final VoidCallback? onTap;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.doseLog,
    required this.onTake,
    required this.onSkip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final isTaken = doseLog.status == DoseStatus.taken;
    final isSkipped = doseLog.status == DoseStatus.skipped;
    final isPending = doseLog.status == DoseStatus.pending;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeFormat.format(doseLog.scheduledTime),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.medication_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${medication.pillsPerDose} ${medication.pillsPerDose == 1 ? 'Pill' : 'Pills'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isPending) ...[
            _ActionButton(
              icon: Icons.check,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              onTap: onTake,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.close,
              color: AppColors.danger,
              backgroundColor: AppColors.dangerLight,
              onTap: onSkip,
            ),
          ] else if (isTaken)
            _ActionButton(
              icon: Icons.check,
              color: Colors.white,
              backgroundColor: AppColors.primary,
              onTap: () {},
            )
          else if (isSkipped)
            _ActionButton(
              icon: Icons.close,
              color: Colors.white,
              backgroundColor: AppColors.danger,
              onTap: () {},
            ),
        ],
      ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
