# Cortex 🧠 (WIP)

**Cortex** is a modern, dynamic, and highly secure block-based note-taking application built with Flutter. It completely reimagines how you write, organize, and protect your thoughts locally on your device.

## 🚀 Key Features

* **Modular Block Editor**: Ditch standard text fields. Write notes utilizing dynamic blocks (Text, Checklists, Images).
* **Drag & Drop**: Effortlessly reorder your blocks via a smooth drag-and-drop interface (`ReorderableListView`).
* **Military-Grade Encryption**: Your privacy is paramount. All notes are encrypted using **AES-GCM** encryption before being saved locally to the database.
* **Biometric Security**: Lock your notes behind a secure Lock Screen powered by native device biometrics (FaceID/Fingerprint) utilizing `local_auth`.
* **Offline-First & Blazing Fast**: Powered by **Isar Database**, meaning your data is stored fully locally and queries happen in milliseconds.
* **Fluid UI & Polish**: Enjoy a premium user experience featuring Glassmorphism design aesthetics, fluid Hero animations, and fully responsive layouts.
* **Native Battery Safeguards**: Custom Kotlin MethodChannels natively ping your Android device's battery level and warn you to save your data if the battery drops below 10%.
* **Full Data Ownership**: Export all your notes directly to JSON for full portability.

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) (Dart)
* **State Management**: [Riverpod](https://riverpod.dev/)
* **Local Database**: [Isar Community](https://isar.dev/)
* **Security & Crypto**: `encrypt`, `flutter_secure_storage`, `local_auth`
* **Architecture**: Clean Architecture (Presentation, Domain, Data layers)

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/       # App colors, strings, text styles
│   └── native/          # Custom MethodChannels (e.g., BatteryService)
├── features/
│   ├── app_core/        # Base navigation and common UI (GlassBottomNav)
│   ├── notes/           # The core note-taking and block-editor logic
│   │   ├── data/        # Isar repositories and models
│   │   ├── domain/      # Sealed classes for Blocks and Notes
│   │   └── presentation/# Note lists, Notifiers, and Edit Screens
│   ├── security/        # Encryption services and Biometric Lock Screen
│   └── settings/        # App preferences and JSON export logic
└── main.dart            # App entry point
```

## 🏗️ Getting Started

### Prerequisites
* Flutter SDK (`>=3.0.0`)
* Android Studio / Xcode for emulators and compilation.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/cortex.git
   cd cortex
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Code** (If you make changes to Isar models or Freezed classes)
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

## 🧪 Testing

The project includes Unit and Widget tests. To run the test suite:
```bash
flutter test
```

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/cortex/issues).

## 📝 License
This project is licensed under the MIT License.
