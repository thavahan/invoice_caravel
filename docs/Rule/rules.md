# Application Rules and Conditions

This document outlines the business rules, validation conditions, and constraints for each module in the Invoice Generator Mobile App.

## 1. Authentication Module

## 2. Orders Module

## 3. Invoice Module

## 4. Master Data Module

## 5. Product Management Module

## 6. Database Services Module

## 7. PDF/Excel Export Services

## 8. Provider/State Management Module

## 9. General Application Rules

### Rule 1: Theme Implementation for New Widgets/Screens
- **Theme Usage**: If any new widget or screen is added in any module, implement theme usage and do not hardcode colors
- **Color Implementation**: Use `Theme.of(context).colorScheme` or `Theme.of(context).primaryColor` instead of hardcoded color values
- **Consistency**: All UI elements must follow the app's theme system for maintainability and dark mode support
- **Functionality Preservation**: Changes must not affect existing functionality - all current features should continue to work as expected

#### Sub-rule 1.1: Data Model and Database Confirmation
- **Confirmation Required**: When adding new widgets or screens, you must ask for confirmation to add corresponding fields in models/tables in database and collections in Firebase
- **No Implementation Without Confirmation**: Do not proceed with data model changes without explicit positive confirmation
- **CRUD Operations**: Upon positive confirmation, implement complete CRUD operations in both SQLite database and Firestore collections
- **Data Synchronization**: Ensure data consistency between local SQLite and Firebase collections

### Rule 2: Removal of Existing Widgets/Screens
- **Theme Cleanup**: When removing existing widgets or screens, ensure no orphaned theme references remain in the codebase
- **Code Cleanup**: Remove all related code, imports, and references to maintain clean codebase
- **Impact Assessment**: Analyze dependencies and cascading effects before removal
- **Functionality Preservation**: Changes must not affect existing functionality - all current features should continue to work as expected

#### Sub-rule 2.1: Data Model and Database Confirmation for Removal
- **Confirmation Required**: When removing widgets or screens, you must ask for confirmation to remove corresponding fields from models/tables in database and collections in Firebase
- **No Implementation Without Confirmation**: Do not proceed with data model removal without explicit positive confirmation
- **CRUD Operations Removal**: Upon positive confirmation, remove related CRUD operations from both SQLite database and Firestore collections
- **Data Migration**: Handle existing data appropriately - either migrate, archive, or remove based on confirmation
- **Data Synchronization**: Ensure clean removal without leaving orphaned data in either storage system
- **Functionality Preservation**: Ensure that removal operations do not break existing data relationships or functionality

### Rule 3: Theme Management and Implementation
- **Theme Provider Usage**: All theme-related operations must use the existing ThemeProvider for state management
- **Color Scheme Consistency**: Use Material Design 3 color schemes with proper primary, secondary, tertiary, and surface colors
- **Dark Mode Support**: All themes must support both light and dark modes with appropriate color adaptations
- **Typography Standards**: Use consistent text themes (display, headline, title, body, label) from Material Design typography scale
- **Component Themes**: Implement component-specific themes for buttons, cards, inputs, and other UI elements
- **Theme Extensions**: Use theme extensions for custom properties like border radius, spacing, and app-specific colors
- **No Hardcoded Values**: Never hardcode colors, fonts, or spacing values - always use theme properties
- **Theme Testing**: Test all screens in both light and dark modes to ensure proper contrast and readability
- **Accessibility**: Ensure themes meet WCAG contrast ratios for text and interactive elements
- **Performance**: Theme changes should not cause unnecessary rebuilds - use proper key management

#### Sub-rule 3.1: Theme Modification Confirmation
- **Confirmation Required**: When modifying existing themes or adding new theme properties, you must ask for confirmation
- **Impact Assessment**: Analyze which screens and components will be affected by theme changes
- **No Implementation Without Confirmation**: Do not proceed with theme modifications without explicit positive confirmation
- **Backward Compatibility**: Ensure theme changes don't break existing functionality or visual consistency
- **Documentation**: Update theme documentation and color palette references after changes

#### Sub-rule 3.2: Theme-Specific Color Handling
- **Adaptive Colors**: When a color works well in one theme but not the other (e.g., visible in dark theme but not in light theme, or vice versa), implement theme-adaptive colors
- **Brightness Detection**: Use `Theme.of(context).brightness` to detect current theme and apply appropriate colors
- **Color Adaptation Strategy**: 
  - For colors that don't work in light theme: Use darker variants or different shades in light mode
  - For colors that don't work in dark theme: Use lighter variants or different shades in dark mode
  - Alternative: Use theme-specific color properties that automatically adapt
- **Contrast Validation**: Always ensure minimum contrast ratios are met in both themes
- **Fallback Colors**: Provide fallback colors that work in both themes when adaptation isn't possible
- **Testing Requirement**: Test color visibility in both light and dark modes before implementation

## 10. Integration Rules

---

*Last Updated: December 24, 2025*
*Version: 1.0*