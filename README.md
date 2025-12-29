# 💊 Pill Reminder App

A beautiful and intuitive Flutter medication reminder app that helps you never miss a dose.

## ✨ Features

### 📋 Medication Management
- ➕ Add medications with custom names and dosages
- 📦 Track pill inventory and stock levels
- 🗑️ Edit or delete medications anytime
- 🎯 Set multiple daily reminder times

### ⏰ Smart Reminders
- 📅 Schedule reminders for specific days of the week
- 🔔 Persistent notifications that keep reminding you
- ⏱️ Notifications repeat every 5 minutes for up to 6 hours if not dismissed
- 🌍 Automatic timezone detection and handling
- 📲 Action buttons directly on notifications (Take/Skip)

### 📊 Dose History
- 📝 Automatic logging when you take or skip medications
- 📈 View complete medication history
- 🗓️ Filter by date and medication
- ✅ Track taken doses
- ⏭️ Track skipped doses

### 🎨 User Interface
- 🌙 Clean, modern Material Design 3
- 📱 Intuitive navigation
- 🎯 Easy-to-use forms
- 📊 Visual inventory tracking
- 🔍 Quick access to all features

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Android Studio / VS Code
- Android device or emulator (Android 6.0+)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/shoeb-gg/pill-reminder.git
   cd pill-reminder
   ```

2. **Navigate to the app directory**
   ```bash
   cd pill_reminder_app
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 How to Use

### Adding a Medication

1. **Tap the ➕ button** on the home screen
2. **Fill in the details:**
   - 💊 Medication name
   - 📋 Dosage (e.g., "500mg", "2 tablets")
   - 🔢 Pills per dose
   - 📦 Total pill count in stock
3. **Set reminder times:**
   - ⏰ Tap "Add Time" to add reminder times
   - 📅 Select which days to be reminded
4. **Save** and you're done!

### Managing Notifications

When a reminder notification appears:
- **✅ Tap "Take"** - Records that you took the medication and decreases stock count
- **⏭️ Tap "Skip"** - Records that you skipped this dose
- **🔄 Swipe away** - Notification will reappear in 5 minutes (repeats for 6 hours)

### Viewing History

1. **Navigate to "Dose History"** tab
2. **Filter by:**
   - 🗓️ Date (tap the date to change)
   - 💊 Medication (use the dropdown)
3. **See all logged doses** with timestamps and status

### Checking Inventory

- 📦 Stock levels shown on each medication card
- ⚠️ Low stock warning when running out
- 🔄 Stock automatically decreases when you take medication
- ✏️ Manually adjust stock in edit screen

## 🏗️ Project Structure

```
pill_reminder_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/                      # Data models
│   │   ├── medication.dart          # Medication model
│   │   └── dose_log.dart            # Dose log model
│   ├── providers/                   # State management
│   │   ├── medication_provider.dart # Medication state
│   │   └── dose_log_provider.dart   # Dose log state
│   ├── screens/                     # UI screens
│   │   ├── home_screen.dart         # Home/medication list
│   │   ├── add_medication_screen.dart
│   │   ├── edit_medication_screen.dart
│   │   ├── dose_history_screen.dart
│   │   └── settings_screen.dart
│   ├── services/                    # Business logic
│   │   └── notification_service.dart # Notification handling
│   └── widgets/                     # Reusable widgets
│       ├── medication_card.dart
│       └── inventory_card.dart
└── pubspec.yaml                     # Dependencies
```

## 🔧 Key Technologies

- **Flutter** - UI framework
- **Riverpod** - State management
- **Hive** - Local database
- **flutter_local_notifications** - Notification system
- **timezone** - Timezone handling
- **Material Design 3** - Design system

## 🔔 Notification System

### How It Works

1. **Initial Setup**
   - App requests notification permissions on first launch
   - Requests exact alarm permissions for precise timing
   - Configures timezone based on device settings

2. **Scheduling**
   - Creates 72 notifications per reminder (one every 5 minutes for 6 hours)
   - Uses notification tags to replace old notifications
   - Repeats weekly on selected days

3. **User Interaction**
   - Take/Skip buttons trigger immediate stock updates
   - All pending reminders for that dose are cancelled
   - If dismissed, next notification appears in 5 minutes

## 🐛 Troubleshooting

### Notifications Not Appearing

1. **Check permissions:**
   - Settings → Apps → Pill Reminder → Notifications: ON
   - Settings → Apps → Pill Reminder → Alarms & reminders: Allow

2. **Check battery optimization:**
   - Settings → Battery → Battery optimization
   - Find "Pill Reminder" and select "Don't optimize"

3. **Verify timezone:**
   - Go to Settings tab
   - Test notifications to verify they work

### Stock Not Decreasing

- Ensure you tap "Take" button (not just dismiss)
- Check that the notification is from today's scheduled time
- Verify in Dose History that the dose was logged

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 👨‍💻 Author

**Shoeb**
- GitHub: [@shoeb-gg](https://github.com/shoeb-gg)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Community packages that made this possible
- All users who provide feedback

---

Made with ❤️ using Flutter
