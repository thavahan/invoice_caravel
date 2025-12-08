# Invoice Generator Documentation

Welcome to the Invoice Generator Mobile App documentation site.

## 📱 Project Overview

The Invoice Generator is a production-ready Flutter mobile application for creating professional invoices with advanced features including Excel export, PDF generation, and offline-first architecture.

## 🚀 Quick Navigation

- **[📖 Complete Documentation](./README.md)** - Full documentation index
- **[🚀 Quick Start Guide](./guides/quick-start.md)** - Get started in 5 minutes  
- **[📱 User Guide](./guides/user-guide.md)** - Complete feature walkthrough
- **[👩‍💻 Developer Guide](./guides/developer.md)** - Development guidelines
- **[🏗️ Architecture](./architecture/overview.md)** - System design and architecture
- **[📋 API Documentation](./api/excel-service.md)** - Service and component docs
- **[🔧 Troubleshooting](./troubleshooting/common-issues.md)** - Common issues and solutions

## ✨ Key Features

- **🧾 Professional Invoice Generation** - Multi-format export (PDF, Excel)
- **⚡ Offline-First Architecture** - Full functionality without internet
- **☁️ Real-time Sync** - Firebase integration with automatic synchronization  
- **📱 Modern UI/UX** - Clean, intuitive interface with immediate response
- **📄 Multi-page PDF Support** - Intelligent pagination for large invoices
- **📊 Master Data Management** - Comprehensive data management system
- **🔍 Advanced Search** - Quick invoice lookup and organization
- **⚡ Performance Optimized** - Sub-100ms response times

## 🛠️ Technology Stack

- **Framework**: Flutter 3.0+
- **Backend**: Firebase Firestore  
- **State Management**: Provider
- **Local Storage**: SQLite
- **PDF Generation**: PDF & Printing packages
- **Excel Export**: Excel package

## 📊 Project Status

| Component | Status | Documentation |
|-----------|--------|―――――――――――――――|
| Core Invoice Generation | ✅ Production Ready | [Excel Service](./api/excel-service.md) |
| PDF Export | ✅ Production Ready | [PDF Service](./api/pdf-service.md) |
| Offline Functionality | ✅ Production Ready | [Architecture](./architecture/overview.md) |
| Real-time Sync | ✅ Production Ready | [Data Flow](./architecture/data-flow.md) |
| Master Data Management | ✅ Production Ready | [Database Services](./api/database.md) |
| Issue Resolution | ✅ All Fixed | [Troubleshooting](./troubleshooting/debugging.md) |

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Presentation  │    │  Business Logic │    │   Data Access   │
│                 │    │                 │    │                 │
│ • Screens       │◄──►│ • DataService   │◄──►│ • Firebase      │
│ • Widgets       │    │ • PDFService    │    │ • SQLite        │
│ • Providers     │    │ • ExcelService  │    │ • File System   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📚 Documentation Structure

```
docs/
├── guides/              # User and developer guides
│   ├── quick-start.md   # Installation and setup
│   ├── user-guide.md    # End-user functionality  
│   └── developer.md     # Development guidelines
├── architecture/        # Technical architecture
│   ├── overview.md      # System architecture
│   ├── data-flow.md     # Data architecture
│   └── services.md      # Service layer docs
├── api/                 # API and service documentation
│   ├── excel-service.md # Excel generation
│   ├── pdf-service.md   # PDF generation
│   └── database.md      # Database services
└── troubleshooting/     # Issue resolution
    ├── common-issues.md # Common problems
    └── debugging.md     # Debug strategies
```

---

**📍 Repository**: [invoice_caravel](https://github.com/thavahan/invoice_caravel)  
**📅 Last Updated**: December 9, 2025  
**✅ Status**: Production Ready