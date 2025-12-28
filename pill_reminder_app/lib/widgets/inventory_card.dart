import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/medication.dart';

class InventoryCard extends StatelessWidget {
  final Medication medication;

  const InventoryCard({
    super.key,
    required this.medication,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = medication.isLowStock;

    return Container(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            medication.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isLow ? AppColors.danger : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${medication.currentStock} remaining',
                style: TextStyle(
                  fontSize: 13,
                  color: isLow ? AppColors.danger : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
