# QuickRide

QuickRide is a motorcycle ride-hailing app designed to transform urban mobility in Rwanda by connecting passengers with motorcycle taxi operators. This README provides step-by-step instructions to set up and run the QuickRide Flutter app.

## Project Overview

QuickRide addresses inefficiencies in rider distribution and fare negotiations for motorcycle taxis (known locally as "motos") in Rwanda. The app connects passengers with riders, optimizes rider allocation, and facilitates transparent fare negotiations.

## Features

- **User Authentication**: Email/password and Google Sign-In
- **Multi-language Support**: English, French, and Kinyarwanda
- **Real-time Location**: Track riders and journeys in real-time
- **Fare Negotiation**: Transparent fare proposals and counter-offers
- **Rating System**: Review and rate rides for better service
- **Ride History**: Track past rides and their details
- **Interactive Maps**: View nearby riders and routes

## Prerequisites

Before starting, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 2.19.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Android Studio](https://developer.android.com/studio) or [Visual Studio Code](https://code.visualstudio.com/) with Flutter extensions
- [Git](https://git-scm.com/)
- A [Firebase](https://firebase.google.com/) account
- A [Google Cloud Platform](https://cloud.google.com/) account for Maps API

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/IrakozeLoraine/quickride_app.git
cd quickride
```

### 2. Install Dependencies

```bash
flutter pub get
```
## Firebase Configuration

### 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter "QuickRide" as the project name
4. Follow the setup wizard to complete the project creation

### 2. Enable Authentication Methods

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Enable "Email/Password" and "Google Sign-in"
3. For Google Sign-in, configure the OAuth consent screen and create credentials in the Google Cloud Console

### 3. Set Up Firestore Database

1. In the Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Start in production mode
4. Choose a location closest to Rwanda (e.g., `europe-west1`)
5. Create the following collections:
   - `users`
   - `riders`
   - `rides`

### 4. Set Up Firestore Security Rules

In the Firebase Console, go to "Firestore Database" > "Rules" and add the following rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /riders/{riderId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == riderId;
    }
    match /rides/{rideId} {
      allow read: if request.auth != null && (
        resource.data.passengerId == request.auth.uid || 
        resource.data.riderId == request.auth.uid
      );
      allow create: if request.auth != null;
      allow update: if request.auth != null && (
        resource.data.passengerId == request.auth.uid || 
        resource.data.riderId == request.auth.uid
      );
    }
  }
}
```

### 5. Add Firebase to Your Flutter App

#### For Android:

1. In the Firebase Console, click "Add App" and select the Android platform
2. Enter the package name `com.lori.quickride` (or your custom package name)
3. Register the app
4. Download the `google-services.json` file
5. Place it in the `android/app` directory

#### For iOS:

1. In the Firebase Console, click "Add App" and select the iOS platform
2. Enter the bundle ID `com.lori.quickride` (or your custom bundle ID)
3. Register the app
4. Download the `GoogleService-Info.plist` file
5. Place it in the `ios/Runner` directory

## Google Maps Configuration

### 1. Get API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select your existing Firebase project
3. Enable the Maps SDK for Android and Maps SDK for iOS
4. Create an API key (For Demo purposes, please use this key: `AIzaSyDfA_oROFwLY7RyCteCbDS-Y4HvjaPpQ1I`)
5. Restrict the API key to your app's package name/bundle ID

### 2. Add API Key to the App

#### For Android:

Edit `android/app/src/main/AndroidManifest.xml` and add:

```xml
<application
    android:name="io.flutter.app.FlutterApplication"
    android:label="QuickRide"
    android:icon="@mipmap/ic_launcher">
    
    <!-- Add this within the application tag -->
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY"/>
    
    <!-- Rest of your manifest -->
</application>
```

#### For iOS:

Edit `ios/Runner/AppDelegate.swift` and add:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Update the API Key in the App Code

Find the line in the code where Google Places API is used and replace "YOUR_GOOGLE_MAPS_API_KEY" with your actual API key:

```dart
GooglePlaceAutoCompleteTextField(
  textEditingController: TextEditingController(),
  googleAPIKey: "YOUR_GOOGLE_MAPS_API_KEY",
  // ...
)
```

## Project Structure

The QuickRide app follows this structure:

```
quickride/
├── android/              # Android-specific files
├── ios/                  # iOS-specific files
├── lib/                  # Dart source code
│   ├── config/           # App configuration
│   ├── core/             # Core utilities and constants
│   ├── data/             # Data models, providers, repositories
│   ├── l10n/             # Localization files
│   ├── presentation/     # UI screens and widgets
│   ├── routes/           # App routing
│   └── main.dart         # Entry point
├── assets/               # App assets
│   └── images/           # Image files
├── pubspec.yaml          # Dependencies and app metadata
└── README.md             # This file
```

## Running the App

### Development Environment

```bash
# Run in debug mode
flutter run

# Run with a specific device
flutter run -d <device_id>

# Get a list of available devices
flutter devices
```

### Build Release Version

```bash
# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

## Troubleshooting

### Common Issues

1. **Ride History Not Working**
   - Check Firestore security rules
   - Verify that the user is properly authenticated
   - Ensure proper indices are created in the Firestore console

2. **Google Maps Not Displaying**
   - Verify the API key is correctly set up
   - Check that billing is enabled on the Google Cloud Console
   - Ensure the Maps SDK is enabled for your platform

3. **Authentication Failures**
   - Check Firebase Authentication is properly enabled
   - Verify the `google-services.json` or `GoogleService-Info.plist` files are in the correct location

4. **Build Failures**
   - Run `flutter clean` followed by `flutter pub get`
   - Check for any conflicting dependencies in `pubspec.yaml`
   - Update Flutter and dependencies to the latest versions

### Firebase Specific Issues

For Firebase-related issues, check the Firestore indices. Some queries require composite indices:

1. Go to the Firebase Console
2. Navigate to Firestore Database > Indices
3. Create these composite indices:
   - Collection: `rides`, Fields: `passengerId` (Ascending) + `createdAt` (Descending)
   - Collection: `rides`, Fields: `riderId` (Ascending) + `createdAt` (Descending)
   - Collection: `rides`, Fields: `passengerId` (Ascending) + `status` (Ascending) + `createdAt` (Descending)
   - Collection: `rides`, Fields: `riderId` (Ascending) + `status` (Ascending) + `createdAt` (Descending)

---
