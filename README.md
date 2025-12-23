# 📱 Invoice Generator Mobile App

> **Production-Ready Flutter Application for Professional Invoice Generation**

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Integrated-orange.svg)](https://firebase.google.com/)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-green.svg)](#)
[![Documentation](https://img.shields.io/badge/Docs-Complete-brightgreen.svg)](./docs/)

## 🚀 Overview

A comprehensive mobile application for generating professional invoices with advanced features including Excel export, PDF generation, offline-first architecture, and real-time synchronization.

### ✨ Key Features

- **📊 Professional Invoice Generation** - Multi-format export (PDF, Excel)
- **🔄 Offline-First Architecture** - Full functionality without internet
- **☁️ Real-time Sync** - Firebase integration with automatic synchronization
- **📱 Modern UI/UX** - Clean, intuitive interface with immediate response
- **🎯 Enhanced PDF Generation** - Intelligent pagination (30 items first page, 40 continuation) - Updated Dec 2025
- **📈 Master Data Management** - Comprehensive shipper, consignee, and product management
- **🔍 Advanced Search & Filtering** - Quick invoice lookup and organization
- **⚡ Performance Optimized** - Sub-100ms response times for common operations

## 📚 Documentation

### Quick Links
- **[📖 Complete Documentation](./docs/)** - Full documentation index
- **[🚀 Quick Start Guide](./docs/guides/quick-start.md)** - Get up and running in 5 minutes
- **[👥 User Guide](./docs/guides/user-guide.md)** - Complete feature walkthrough
- **[👩‍💻 Developer Guide](./docs/guides/developer.md)** - Development guidelines
- **[🏗️ Architecture Overview](./docs/architecture/overview.md)** - Technical architecture and design decisions
- **[📋 API Reference](./docs/api/excel-service.md)** - Service and component documentation
- **[🔧 Troubleshooting](./docs/troubleshooting/common-issues.md)** - Common issues and solutions

### Documentation Structure

```
docs/
├── guides/              # User and developer guides
│   ├── quick-start.md   # Installation and setup
│   ├── user-guide.md    # End-user functionality
│   └── developer.md     # Development guidelines
├── architecture/        # Technical architecture
│   ├── overview.md      # System architecture
│   ├── data-flow.md     # Data architecture and flow
│   └── services.md      # Service layer documentation
├── api/                 # API and service documentation
│   ├── excel-service.md # Excel generation service
│   ├── pdf-service.md   # PDF generation service
│   └── database.md      # Database services
└── troubleshooting/     # Issue resolution
    ├── common-issues.md # Frequently encountered issues
    └── debugging.md     # Debug strategies and fixes
```

## ⚡ Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Firebase account
- Android Studio / VS Code

### Installation

```bash
# Clone the repository
git clone https://github.com/thavahan/invoice_caravel.git
cd invoice_caravel

# Install dependencies
flutter pub get

# Run the application
flutter run
```

### Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication and Firestore
3. Download configuration files:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`

**📖 [Detailed Setup Instructions](./docs/guides/quick-start.md)**

## 🏗️ Architecture

### Tech Stack

| Component | Technology | Purpose |
|-----------|------------|----------|
| **Framework** | Flutter 3.0+ | Cross-platform mobile development |
| **Backend** | Firebase Firestore | Cloud database and authentication |
| **State Management** | Provider | Scalable state management |
| **Local Storage** | SQLite | Offline-first data persistence |
| **PDF Generation** | PDF & Printing packages | Professional document generation |
| **Excel Export** | Excel package | Spreadsheet generation |
| **Logging** | Logger package | Comprehensive debugging |

### Project Structure

```
lib/
├── models/          # Data models (Shipment, Product, etc.)
├── providers/       # State management (InvoiceProvider, etc.)
├── screens/         # UI screens and pages
│   ├── auth/        # Authentication screens
│   ├── invoice/     # Invoice management
│   └── master_data/ # Master data management
├── services/        # Business logic layer
│   ├── data_service.dart      # Unified data coordination
│   ├── excel_file_service.dart # Excel generation
│   ├── pdf_service.dart       # PDF generation
│   └── firebase_service.dart  # Firebase integration
└── widgets/         # Reusable UI components
```

## 🔧 Development

### Key Architectural Decisions

- **Offline-First**: All read operations use local database for instant response
- **Dual-Persistence**: Write operations save to both local and cloud storage
- **Service Layer**: Clear separation between UI, business logic, and data access
- **Provider Pattern**: Centralized state management with reactive UI updates

### Performance Features

- **⚡ Sub-100ms Response**: Local-first architecture ensures instant UI updates
- **📊 Intelligent Pagination**: Automatic multi-page PDF generation
- **🔄 Background Sync**: Non-blocking data synchronization
- **💾 Smart Caching**: Optimized memory and storage usage

## 📈 Status

| Feature | Status | Documentation |
|---------|--------|--------------|
| **Core Invoice Generation** | ✅ Production Ready | [Excel Service](./docs/api/excel-service.md) |
| **PDF Export** | ✅ Production Ready | [PDF Service](./docs/api/pdf-service.md) |
| **Offline Functionality** | ✅ Production Ready | [Architecture](./docs/architecture/overview.md) |
| **Real-time Sync** | ✅ Production Ready | [Data Flow](./docs/architecture/data-flow.md) |
| **Master Data Management** | ✅ Production Ready | [Database Services](./docs/api/database.md) |
| **Issue Resolution** | ✅ All Issues Fixed | [Troubleshooting](./docs/troubleshooting/debugging.md) |

## 🤝 Contributing

1. Read the [Development Guide](./docs/guides/developer.md)
2. Check [Architecture Documentation](./docs/architecture/overview.md)
3. Review [API Documentation](./docs/api/excel-service.md)
4. Follow established patterns and conventions
5. See [Contributing Guidelines](./CONTRIBUTING.md)

## 📄 License

This project is private and proprietary.

---

**📖 For complete documentation, visit [./docs/](./docs/)**
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
