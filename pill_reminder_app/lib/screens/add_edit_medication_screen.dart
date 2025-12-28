import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../models/medication.dart';
import '../providers/medication_provider.dart';

class AddEditMedicationScreen extends ConsumerStatefulWidget {
  final Medication? medication;

  const AddEditMedicationScreen({super.key, this.medication});

  @override
  ConsumerState<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState
    extends ConsumerState<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _stockController;
  late TextEditingController _thresholdController;
  late TextEditingController _notesController;

  int _pillsPerDose = 1;
  int _colorIndex = 0;
  List<TimeOfDay> _scheduledTimes = [];
  List<int> _reminderDays = []; // No days selected by default

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _nameController = TextEditingController(text: med?.name ?? '');
    _dosageController = TextEditingController(text: med?.dosage ?? '');
    _stockController =
        TextEditingController(text: med != null ? med.currentStock.toString() : '');
    _thresholdController =
        TextEditingController(text: med != null ? med.lowStockThreshold.toString() : '');
    _notesController = TextEditingController(text: med?.notes ?? '');

    if (med != null) {
      _pillsPerDose = med.pillsPerDose;
      _colorIndex = med.colorIndex;
      _reminderDays = List.from(med.reminderDays);
      _scheduledTimes = med.scheduledTimes.map((timeStr) {
        final parts = timeStr.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Name field
            _buildLabel('Medication Name'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g., Lisinopril',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a medication name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Dosage field (optional)
            _buildLabel('Dosage'),
            TextFormField(
              controller: _dosageController,
              decoration: const InputDecoration(
                hintText: 'e.g., 10mg',
              ),
            ),
            const SizedBox(height: 20),

            // Pills per dose
            _buildLabel('Pills Per Dose'),
            Row(
              children: [
                _CounterButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_pillsPerDose > 1) {
                      setState(() => _pillsPerDose--);
                    }
                  },
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController(text: '$_pillsPerDose'),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 1) {
                        setState(() => _pillsPerDose = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _CounterButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _pillsPerDose++),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Schedule times
            _buildLabel('Schedule Times'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._scheduledTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return _TimeChip(
                    time: time,
                    onTap: () => _editTime(index),
                    onDelete: () {
                      setState(() => _scheduledTimes.removeAt(index));
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add Time'),
                  onPressed: _addTime,
                  backgroundColor: AppColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reminder days
            _buildLabel('Reminder Days'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildDayChip('S', 6),
                  _buildDayChip('S', 7),
                  _buildDayChip('M', 1),
                  _buildDayChip('T', 2),
                  _buildDayChip('W', 3),
                  _buildDayChip('T', 4),
                  _buildDayChip('F', 5),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stock (optional)
            _buildLabel('Current Stock'),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Number of pills',
              ),
            ),
            const SizedBox(height: 20),

            // Low stock threshold (optional)
            _buildLabel('Low Stock Alert Threshold'),
            TextFormField(
              controller: _thresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Alert when pills fall below this number',
              ),
            ),
            const SizedBox(height: 20),

            // Color picker
            _buildLabel('Pill Color'),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: AppColors.pillColors.length,
                itemBuilder: (context, index) {
                  final isSelected = _colorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _colorIndex = index),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.pillColors[index],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.textPrimary, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            _buildLabel('Notes'),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any additional notes...',
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _saveForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isEditing ? 'Update Medication' : 'Add Medication'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _scheduledTimes.add(time));
    }
  }

  void _editTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTimes[index],
    );
    if (time != null) {
      setState(() => _scheduledTimes[index] = time);
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_reminderDays.contains(day)) {
        _reminderDays.remove(day);
      } else {
        _reminderDays.add(day);
        _reminderDays.sort();
      }
    });
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _reminderDays.contains(day);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => _toggleDay(day),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? null : Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) return;

    if (_scheduledTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one schedule time'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final scheduledTimesStr = _scheduledTimes
        .map((t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    final currentStock = int.tryParse(_stockController.text) ?? 0;
    final lowStockThreshold = int.tryParse(_thresholdController.text) ?? 10;

    if (_isEditing) {
      final updated = widget.medication!.copyWith(
        name: _nameController.text,
        dosage: _dosageController.text,
        pillsPerDose: _pillsPerDose,
        scheduledTimes: scheduledTimesStr,
        currentStock: currentStock,
        lowStockThreshold: lowStockThreshold,
        colorIndex: _colorIndex,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        reminderDays: _reminderDays,
      );
      ref.read(medicationsProvider.notifier).updateMedication(updated);
    } else {
      ref.read(medicationsProvider.notifier).addMedication(
            name: _nameController.text,
            dosage: _dosageController.text,
            pillsPerDose: _pillsPerDose,
            scheduledTimes: scheduledTimesStr,
            currentStock: currentStock,
            lowStockThreshold: lowStockThreshold,
            colorIndex: _colorIndex,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            reminderDays: _reminderDays,
          );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Medication updated' : 'Medication added'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TimeChip({
    required this.time,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(timeStr),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDelete,
        backgroundColor: AppColors.card,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

