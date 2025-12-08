# 🚀 Quick Start Guide - Invoice Generator Mobile App

**Get up and running with the Invoice Generator in under 5 minutes**

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

### Required Software
- **[Flutter SDK 3.0+](https://flutter.dev/docs/get-started/install)** - Cross-platform mobile development
- **[Android Studio](https://developer.android.com/studio)** or **[VS Code](https://code.visualstudio.com/)** - IDE
- **[Git](https://git-scm.com/)** - Version control
- **[Firebase Account](https://console.firebase.google.com/)** - Backend services

### Development Environment
- **Android**: Android SDK, Android device or emulator
- **iOS** (macOS only): Xcode, iOS device or simulator

## 🛠️ Installation

### 1. Clone the Repository

```bash
# Clone the project
git clone https://github.com/thavahan/invoice_caravel.git
cd invoice_caravel

# Verify Flutter installation
flutter doctor
```

### 2. Install Dependencies

```bash
# Get all Flutter dependencies
flutter pub get

# Verify no issues
flutter analyze
```

### 3. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"**
3. Enter project name: `invoice-generator-app`
4. Enable Google Analytics (optional)
5. Click **"Create project"**

#### Enable Required Services
```
✅ Authentication (Email/Password)
✅ Cloud Firestore (Database)
✅ Cloud Storage (File storage)
```

#### Download Configuration Files

**For Android:**
1. Click **"Add app"** → **"Android"**
2. Package name: `com.techsultan.invoice_generator`
3. Download `google-services.json`
4. Place in: `android/app/google-services.json`

**For iOS:**
1. Click **"Add app"** → **"iOS"**
2. Bundle ID: `com.techsultan.invoiceGenerator`
3. Download `GoogleService-Info.plist`
4. Place in: `ios/Runner/GoogleService-Info.plist`

### 4. Configure Firestore Security Rules

```javascript
// In Firebase Console → Firestore Database → Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Run the Application

```bash
# List available devices
flutter devices

# Run on connected device
flutter run

# Or run in debug mode with hot reload
flutter run --debug
```

## ✅ Verification

### Check Installation Success

1. **App Launch**: App opens without crashes
2. **Authentication**: Login/signup screens appear
3. **Database Connection**: Can create and save invoices
4. **Export Functions**: PDF and Excel export work

### Test Core Features

```bash
# Run tests to verify installation
flutter test

# Build release version to test
flutter build apk --debug
```

## 🎯 First Steps

### 1. Create Your Account
- Open the app
- Tap **"Sign Up"**
- Enter email and password
- Verify email (check spam folder)

### 2. Set Up Master Data
- **Shippers**: Add your company information
- **Consignees**: Add customer details
- **Product Types**: Configure product categories

### 3. Create Your First Invoice
- Tap **"Create Invoice"**
- Fill in shipment details
- Add boxes and products
- Generate PDF/Excel export

## 🔧 Configuration Options

### Development Mode
```bash
# Enable debug mode
flutter run --debug --flavor development
```

### Production Build
```bash
# Build release APK
flutter build apk --release

# Build iOS release
flutter build ios --release
```

## 🚨 Common Issues

### Flutter Issues
```bash
# Clear Flutter cache
flutter clean && flutter pub get

# Reset Flutter
flutter doctor --android-licenses
```

### Firebase Issues
- **Connection Failed**: Check `google-services.json` placement
- **Auth Not Working**: Verify Firebase project settings
- **Data Not Syncing**: Check Firestore security rules

### Build Issues
```bash
# Update dependencies
flutter pub upgrade

# Check for conflicts
flutter pub deps
```

## 📚 Next Steps

After successful installation:

1. **[Read the User Guide](./user-guide.md)** - Learn all features
2. **[Check Architecture Docs](../architecture/)** - Understand the system
3. **[Review API Documentation](../api/)** - Service details
4. **[Development Guidelines](./developer.md)** - Contributing guide

## 🆘 Getting Help

- **Documentation Issues**: Check [troubleshooting guide](../troubleshooting/)
- **Feature Questions**: Review [user guide](./user-guide.md)
- **Development Help**: See [developer guide](./developer.md)
- **Bug Reports**: Create GitHub issue with details

---

**⏱️ Estimated Setup Time**: 5-15 minutes  
**✅ Success Criteria**: App runs and can create/export invoices  
**📍 Next**: [Complete User Guide](./user-guide.md)