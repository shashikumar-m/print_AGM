# PrintHub Flutter App

Mobile app for the PrintHub smart student printing system.

## Setup

### 1. Set your server URL

Open `lib/services/api_service.dart` and update the base URL:

```dart
static const String baseUrl = 'https://your-server-url.com/api';
```

Replace `https://print-agm.onrender.com/api` with your actual hosted server URL.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

### 4. Build APK for Android

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

### 5. Build for iOS

```bash
flutter build ios --release
```

## Features

### Student
- Login / Register
- View wallet balance
- Upload PDF and submit for printing
- Duplex printing option
- Real-time upload progress

### Admin
- View all students and their wallet balances
- Add funds to student wallets
- View all print jobs with status
- Update price per page

## Project Structure

```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart          # Colors, typography, component themes
├── models/
│   ├── user_model.dart
│   └── print_job_model.dart
├── services/
│   ├── api_service.dart        # All HTTP calls to your server
│   └── auth_service.dart       # Token + user session storage
├── screens/
│   ├── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── student/
│   │   ├── student_dashboard.dart
│   │   └── upload_screen.dart
│   └── admin/
│       ├── admin_dashboard.dart
│       ├── students_tab.dart
│       ├── print_jobs_tab.dart
│       └── settings_tab.dart
└── widgets/
    ├── custom_text_field.dart
    └── loading_button.dart
```
