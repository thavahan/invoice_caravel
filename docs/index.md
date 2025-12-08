# Invoice Generator Documentation

Welcome to the Invoice Generator Mobile App documentation site.

## 📱 Project Overview

The Invoice Generator is a production-ready Flutter mobile application for creating professional invoices with advanced features including Excel export, PDF generation, and offline-first architecture.

## 🚀 Quick Navigation

- **[📖 Complete Documentation](./docs/)** - Full documentation index
- **[🚀 Quick Start Guide](./docs/guides/quick-start.html)** - Get started in 5 minutes  
- **[📱 User Guide](./docs/guides/user-guide.html)** - Complete feature walkthrough
- **[👩‍💻 Developer Guide](./docs/guides/developer.html)** - Development guidelines
- **[🏗️ Architecture](./docs/architecture/)** - System design and architecture
- **[📡 API Documentation](./docs/api/)** - Service and component docs
- **[🔧 Troubleshooting](./docs/troubleshooting/)** - Common issues and solutions

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
|-----------|--------|---------------|
| Core Invoice Generation | ✅ Production Ready | [Excel Service](./docs/api/excel-service.html) |
| PDF Export | ✅ Production Ready | [PDF Service](./docs/api/pdf-service.html) |
| Offline Functionality | ✅ Production Ready | [Architecture](./docs/architecture/overview.html) |
| Real-time Sync | ✅ Production Ready | [Data Flow](./docs/architecture/data-flow.html) |
| Master Data Management | ✅ Production Ready | [Database Services](./docs/api/database.html) |
| Issue Resolution | ✅ All Fixed | [Troubleshooting](./docs/troubleshooting/) |

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