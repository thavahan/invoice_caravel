# Flutter Invoice Generator

A professional and production-ready mobile app to generate invoices, built with Flutter. This project is a complete overhaul of the original, focusing on a robust architecture, clean code, and a better user experience.

## Key Features
- **Modern UI/UX:** A clean and user-friendly interface.
- **State Management:** Uses the `provider` package for scalable and maintainable state management.
- **Robust Backend:** Fully integrated with Cloud Firestore for all database operations.
- **PDF Generation:** Generate, preview, and share professional-looking invoices as PDFs.
- **Error Handling & Logging:** Implemented robust error handling and logging for easier debugging.
- **Tested:** Includes unit and widget tests to ensure functionality and prevent regressions.

## Tech Stack
- **Flutter & Dart**
- **Firebase:** Cloud Firestore for the database.
- **Provider:** For state management.
- **PDF & Printing:** For PDF generation and handling.
- **Logger:** For logging.
- **Mockito:** For testing.

## Project Structure
The project has been refactored into a clean and scalable architecture:
```
lib/
├── models/         # Data models for the app (Invoice, Product, etc.)
├── providers/      # ChangeNotifier classes for state management
├── screens/        # UI screens for the app
├── services/       # Services for interacting with external resources (Firebase, PDF)
└── main.dart       # The main entry point of the app
```

## Getting Started
To get a local copy up and running, follow these simple steps.

### Prerequisites
- Flutter SDK: Make sure you have the Flutter SDK installed.
- A Firebase project: You'll need a Firebase project to connect the app to a backend.

### Installation
1. **Clone the repo**
   ```sh
   git clone https://github.com/your_username_/your_repository.git
   ```
2. **Install packages**
   ```sh
   flutter pub get
   ```
3. **Set up Firebase**
   - Create a new Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/).
   - Add an Android and/or iOS app to your Firebase project.
   - Follow the instructions to download the `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) files.
   - Place the `google-services.json` file in the `android/app/` directory.
   - Place the `GoogleService-Info.plist` file in the `ios/Runner/` directory.
4. **Set up Firestore**
   - In your Firebase project, create a Cloud Firestore database.
   - Create the following collections with some sample data:
     - `products`: with fields `Product Name`, `Type`, `Pack size`, `Unit Price`.
     - `customers`: with fields `Party Name`, `Address`.
     - `resources`: with a document named `config` and a field `signURL` (a URL to an image for the signature).

## Usage
Run the app using the following command:
```sh
flutter run
```

## Contributing
Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Contact
contact@tanvirrobin.dev
