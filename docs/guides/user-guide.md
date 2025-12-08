# 👥 User Guide - Invoice Generator Mobile App

**Complete feature walkthrough and user manual**

## 🎯 Overview

The Invoice Generator Mobile App is designed for businesses that need to create professional invoices quickly and efficiently. The app works offline-first, meaning you can create and manage invoices even without an internet connection.

## 📱 Getting Started

### First Launch
1. **Download and Install** - Follow the [Quick Start Guide](./quick-start.md)
2. **Create Account** - Sign up with email and password
3. **Initial Setup** - Configure your business information

### App Navigation
- **Bottom Navigation**: Quick access to main sections
- **Search**: Find invoices quickly with advanced filters
- **Menu**: Access settings and additional features

## 🏢 Master Data Management

### Shipper Management
**Purpose**: Manage your company/sender information

**How to Add Shippers:**
1. Go to **Settings** → **Master Data** → **Shippers**
2. Tap **"+ Add Shipper"**
3. Fill in details:
   - Company Name
   - Contact Person
   - Address (Street, City, State, Country, ZIP)
   - Phone, Email, Website

**Tips:**
- Add multiple locations if you have offices in different cities
- Keep contact information current for professional communication
- Use consistent naming for easy selection

### Consignee Management
**Purpose**: Manage customer/recipient information

**How to Add Consignees:**
1. Go to **Settings** → **Master Data** → **Consignees**
2. Tap **"+ Add Consignee"**
3. Enter customer details:
   - Business/Person Name
   - Complete Address
   - Contact Information

**Best Practices:**
- Verify addresses for accurate delivery
- Save frequently used customers for quick access
- Include multiple contact methods when available

### Product Types
**Purpose**: Define product categories with pricing

**Configuration:**
1. **Settings** → **Master Data** → **Product Types**
2. Add product categories:
   - Product Name/Type
   - Default Rate (price per kg)
   - Approximate Quantity per Kg

**Usage:**
- Automatically calculates quantities based on weight
- Standardizes pricing across invoices
- Speeds up invoice creation

## 📄 Invoice Creation

### Creating a New Invoice

#### Step 1: Basic Information
1. Tap **"+ Create Invoice"** on home screen
2. Fill in shipment details:
   - **Invoice Number**: Auto-generated or custom
   - **AWB (Airway Bill)**: Tracking reference
   - **Invoice Title**: Descriptive name
   - **Flight Details**: Date, flight number, airports
   - **Shipper**: Select from master data
   - **Consignee**: Select customer

#### Step 2: Adding Boxes
1. Tap **"+ Add Box"**
2. Enter box details:
   - **Box Number**: Unique identifier
   - **Dimensions**: Length × Width × Height (cm)
   - **Weight**: Total box weight (kg)

#### Step 3: Adding Products to Boxes
1. Select a box
2. Tap **"+ Add Product"**
3. Configure product:
   - **Product Type**: Select from master data
   - **Weight**: Product weight (kg)
   - **Rate**: Price per kg (auto-filled)
   - **Description**: Product details
   - **Special Options**: Flower type, stems, etc.

**Auto-Calculation Features:**
- **Approximate Quantity**: Weight × quantity per kg
- **Amount**: Weight × rate
- **Total**: Automatic sum of all products

### Draft Management
- **Auto-Save**: Drafts save automatically as you work
- **Resume Later**: Continue editing from where you left off
- **Multiple Drafts**: Work on several invoices simultaneously

## 📤 Export and Sharing

### PDF Generation
**Professional multi-page PDFs with automatic pagination**

1. Complete invoice creation
2. Tap **"Generate PDF"**
3. Preview the generated document
4. Options:
   - **Share**: Email, messaging, cloud storage
   - **Print**: Direct wireless printing
   - **Save**: Store to device storage

**PDF Features:**
- Professional formatting
- Company branding
- Automatic page breaks for large invoices
- Summary tables and totals

### Excel Export
**Comprehensive spreadsheets for accounting**

1. From invoice list, select invoice
2. Tap **"Export to Excel"**
3. Professional Excel file generated with:
   - Invoice header and details
   - Itemized product lists
   - Calculated totals
   - Professional formatting

**Excel Benefits:**
- Import into accounting software
- Custom calculations and analysis
- Archive in existing workflows

## 📊 Invoice Management

### Invoice List
**Central hub for all your invoices**

**Features:**
- **Search**: Find by invoice number, customer, or content
- **Filter**: Date ranges, status, customer
- **Sort**: Date, amount, customer name
- **Status Tracking**: Draft, completed, sent

**Quick Actions:**
- **Tap to View**: See invoice details
- **Swipe Options**: Edit, delete, duplicate
- **Bulk Actions**: Export multiple invoices

### Editing Existing Invoices
1. Select invoice from list
2. Tap **"Edit"**
3. Make changes to any section
4. **Save** or **Save as New Draft**

**Important**: Editing published invoices creates a new version

### Invoice Status Management
- **Draft**: Work in progress
- **Completed**: Ready for export
- **Sent**: Delivered to customer
- **Archived**: Completed business

## 🔄 Sync and Offline Features

### Offline Capability
**Full functionality without internet connection**

**What Works Offline:**
- Create and edit invoices
- Generate PDFs and Excel files
- Access all master data
- Search and filter invoices

**Automatic Sync:**
- Changes sync when connection returns
- Background synchronization
- No data loss during offline periods

### Cloud Backup
**Automatic backup to Firebase**

**Benefits:**
- Access from multiple devices
- Automatic data protection
- Seamless device switching
- Collaborative access (if configured)

## ⚙️ Settings and Customization

### App Settings
- **Theme**: Light/dark mode preferences
- **Export Options**: Default formats and quality
- **Backup Settings**: Sync frequency and preferences
- **Language**: Interface language selection

### Business Configuration
- **Company Branding**: Logo and colors
- **Default Templates**: Invoice layouts
- **Numbering**: Invoice number formats
- **Currency**: Primary business currency

## 🔍 Search and Filters

### Quick Search
- **Global Search**: Search across all invoices
- **Smart Suggestions**: Recent and frequent items
- **Voice Search**: Speak your query

### Advanced Filters
- **Date Range**: Specific periods
- **Customer**: Filter by consignee
- **Amount Range**: Invoice value filters
- **Status**: Draft, completed, sent
- **Product Type**: Filter by products

## 📈 Reports and Analytics

### Invoice Reports
- **Monthly Summaries**: Revenue and volume
- **Customer Reports**: Top customers and trends
- **Product Analysis**: Best-selling products
- **Export Reports**: PDF and Excel formats

### Business Insights
- **Revenue Tracking**: Monthly and yearly trends
- **Customer Insights**: Purchase patterns
- **Product Performance**: Volume and revenue by product
- **Growth Metrics**: Business development indicators

## 🚨 Troubleshooting

### Common Issues

**Invoice Won't Save**
- Check all required fields are filled
- Ensure valid email format
- Try saving as draft first

**Export Fails**
- Check device storage space
- Verify permissions for file access
- Try smaller invoices first

**Sync Problems**
- Check internet connection
- Verify Firebase credentials
- Force sync from settings

**Performance Issues**
- Clear app cache in settings
- Restart the application
- Check available device memory

### Getting Help
- **In-App Help**: Tap "?" for contextual help
- **Documentation**: Complete guides in docs folder
- **Support**: Contact support through app settings

## 🎓 Tips and Best Practices

### Efficiency Tips
1. **Master Data First**: Set up all master data before creating invoices
2. **Templates**: Use consistent product types and pricing
3. **Batch Processing**: Create similar invoices together
4. **Regular Backup**: Ensure sync is enabled and working

### Professional Invoicing
1. **Consistent Numbering**: Use systematic invoice numbers
2. **Complete Information**: Fill all relevant fields
3. **Accurate Descriptions**: Clear product descriptions
4. **Timely Generation**: Create invoices promptly after service

### Data Management
1. **Regular Cleanup**: Archive old invoices periodically
2. **Backup Verification**: Test restore capabilities
3. **Update Contacts**: Keep customer information current
4. **Version Control**: Track invoice revisions properly

---

**📱 App Version**: 3.0+  
**📅 Updated**: December 2025  
**🆘 Support**: Available through app settings  
**📖 More Help**: [Troubleshooting Guide](../troubleshooting/common-issues.md)