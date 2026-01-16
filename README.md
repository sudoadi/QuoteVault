# QuoteVault 🚀
 Check Releases for apk builds.
 
A modern, high-performance Flutter application for discovering, collecting, and sharing daily wisdom. Features a futuristic UI, Home Screen Widgets, and Local Notifications.

## 🌟 Features

* **Daily Inspiration**: A new quote every day, synced with Supabase.
* **Home Screen Widget**: View your daily quote directly from your Android home screen.
* **Interactive Notifications**: Get daily alerts with "Open" and "Like" actions.
* **Agent Profile**: A gamified profile card with flip animation and QR code sharing.
* **Collections**: Bookmark quotes into custom collections.
* **Dynamic Theming**: Custom signature colors and dark/light mode toggle.

## 🛠 Tech Stack

* **Framework**: Flutter (Dart)
* **Backend**: Supabase (PostgreSQL, Auth, Storage)
* **State Management**: `setState` & `ValueNotifier`
* **Local Data**: `shared_preferences`
* **Native Integration**: `home_widget` (Android XML), `flutter_local_notifications`

## 🚀 Setup Instructions

### 1. Prerequisites
* Flutter SDK (3.0+)
* Android Studio / VS Code
* Supabase Account

### 2. Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/yourusername/quotevault.git](https://github.com/yourusername/quotevault.git)
    cd quotevault
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Supabase:**
    * Open `lib/config/constants.dart`.
    * Replace `supabaseUrl` and `supabaseAnonKey` with your project credentials.

4.  **Run the App:**
    ```bash
    flutter run
    ```

## 📱 Architecture

The project follows a modular, feature-first architecture:
