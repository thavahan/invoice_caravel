# 🤝 Contributing to Invoice Generator Documentation

Thank you for your interest in contributing to the Invoice Generator Mobile App documentation. This guide will help you contribute effectively and maintain our documentation standards.

## 📋 Documentation Standards

### File Organization
```
docs/
├── README.md              # Main documentation index
├── index.md               # GitHub Pages homepage
├── guides/                # User and developer guides
├── architecture/          # Technical architecture docs
├── api/                   # Service API documentation
└── troubleshooting/       # Issue resolution guides
```

### Naming Conventions
- **Files**: Use kebab-case: `quick-start.md`, `user-guide.md`
- **Directories**: Use lowercase: `guides/`, `api/`, `architecture/`
- **Headers**: Use descriptive titles with appropriate emojis
- **IDs**: Use lowercase with hyphens for anchor links

### Content Standards

#### Markdown Format
```markdown
# 📱 Page Title with Emoji

**Brief description of the document purpose**

## 🎯 Section Header

### Subsection Header

Content with proper formatting:
- **Bold** for important terms
- `code` for inline code
- **[Links](./other-doc.md)** for cross-references

```dart
// Code blocks with language specification
class ExampleCode {
  void method() {
    // Clear comments
  }
}
```

#### Table Format
| Column 1 | Column 2 | Status |
|----------|----------|--------|
| Item | Description | ✅ Complete |
```

#### Documentation Headers
Every documentation file should start with:
```markdown
# 📱 [Title] - Invoice Generator Mobile App

**[One-line description of purpose and audience]**

## 📋 Overview
[Brief overview of what this document covers]
```

## ✍️ Writing Guidelines

### Tone and Style
- **Clear and Concise**: Use simple, direct language
- **Professional but Friendly**: Maintain professional tone with helpful approach
- **Consistent Terminology**: Use the same terms throughout documentation
- **Action-Oriented**: Use active voice and clear instructions

### Content Structure
1. **Overview**: Brief introduction to the topic
2. **Prerequisites**: What users need before starting
3. **Step-by-Step Instructions**: Clear, numbered steps
4. **Examples**: Practical code examples and screenshots
5. **Troubleshooting**: Common issues and solutions
6. **Next Steps**: Links to related documentation

### Code Examples
```dart
// ✅ GOOD: Clear, commented examples
/// Creates a new invoice with the specified details
Future<String> createInvoice(InvoiceData data) async {
  // Validate input data
  if (data.isEmpty) {
    throw ValidationException('Invoice data cannot be empty');
  }
  
  // Save to local database first
  final id = await _localService.saveInvoice(data);
  
  // Sync to cloud (non-blocking)
  _cloudService.syncInvoice(data);
  
  return id;
}

// ❌ AVOID: Unclear or uncommented code
Future<String> create(var d) async {
  if (d.isEmpty) throw Exception('empty');
  var x = await ls.save(d);
  cs.sync(d);
  return x;
}
```

## 🔄 Contribution Process

### 1. Setup Development Environment
```bash
# Fork and clone the repository
git clone https://github.com/[your-username]/invoice_caravel.git
cd invoice_caravel

# Create a documentation branch
git checkout -b docs/feature-name

# Make your changes in the docs/ directory
```

### 2. Making Changes
- **Edit Existing Docs**: Update content while maintaining structure
- **Add New Docs**: Follow the established format and organization
- **Update Links**: Ensure all internal links work correctly
- **Test Locally**: Preview your changes before submitting

### 3. Quality Checklist
Before submitting, verify:
- [ ] **Spelling and Grammar**: Use spell check and proofread
- [ ] **Links Work**: All internal and external links function
- [ ] **Code Examples**: All code compiles and runs
- [ ] **Screenshots**: Images are current and relevant
- [ ] **Navigation**: Document fits logically in navigation structure
- [ ] **Cross-References**: Related documents are linked

### 4. Pull Request Process
```bash
# Commit your changes
git add docs/
git commit -m "docs: add user guide for invoice export"

# Push to your fork
git push origin docs/feature-name

# Create pull request on GitHub
```

#### PR Description Template
```markdown
## Documentation Changes

**Type of Change**
- [ ] New documentation
- [ ] Update existing documentation
- [ ] Fix typos/grammar
- [ ] Restructure content
- [ ] Add examples

**Description**
Brief description of what was added/changed and why.

**Files Changed**
- `docs/guides/new-feature.md` - Added comprehensive guide
- `docs/README.md` - Updated navigation links

**Testing**
- [ ] Links verified
- [ ] Code examples tested
- [ ] Screenshots updated
- [ ] Navigation works

**Related Issues**
Closes #[issue-number]
```

## 📝 Content Guidelines

### User-Focused Content
- **Know Your Audience**: Tailor content for specific user types
- **Provide Context**: Explain why something is important
- **Include Examples**: Show real-world usage scenarios
- **Anticipate Questions**: Address common concerns proactively

### Technical Documentation
- **Be Comprehensive**: Cover all parameters and options
- **Show Error Cases**: Document common errors and solutions
- **Include Performance Notes**: Mention performance implications
- **Version Information**: Specify version requirements

### Maintenance Guidelines
- **Keep Current**: Update docs with code changes
- **Review Regularly**: Quarterly review for accuracy
- **Monitor Feedback**: Address user questions and issues
- **Archive Outdated**: Remove or archive obsolete information

## 🎨 Visual Guidelines

### Screenshots and Images
- **High Quality**: Use high-resolution images
- **Consistent**: Same device/browser/theme for uniformity
- **Annotated**: Highlight relevant areas with arrows/callouts
- **Current**: Keep screenshots updated with latest UI

### Diagrams and Charts
- **Professional**: Use consistent styling and colors
- **Readable**: Ensure text is large enough to read
- **Accessible**: Include alt text for screen readers
- **Version Control**: Use text-based formats when possible

## 🔍 Review Process

### Documentation Review
1. **Technical Accuracy**: Code examples work correctly
2. **Content Quality**: Clear, comprehensive, and helpful
3. **Style Consistency**: Follows established guidelines
4. **Navigation**: Fits well in overall structure
5. **User Experience**: Easy to find and understand

### Review Checklist
- [ ] **Grammar and Spelling**: No errors
- [ ] **Technical Accuracy**: Information is correct
- [ ] **Code Examples**: All examples work
- [ ] **Link Validation**: All links function properly
- [ ] **Mobile Friendly**: Readable on mobile devices
- [ ] **Accessibility**: Meets accessibility standards

## 🛠️ Tools and Resources

### Recommended Tools
- **Editor**: VS Code with Markdown extensions
- **Preview**: Use VS Code markdown preview or GitHub preview
- **Spell Check**: Grammarly or VS Code spell check
- **Link Checking**: Use markdown-link-check tool

### Resources
- **[Markdown Guide](https://www.markdownguide.org/)** - Markdown syntax reference
- **[GitHub Docs](https://docs.github.com/)** - GitHub documentation examples
- **[Write the Docs](https://www.writethedocs.org/)** - Documentation community

## 📞 Getting Help

### Questions and Support
- **GitHub Issues**: Create an issue for documentation questions
- **Discussions**: Use GitHub Discussions for broader topics
- **Community**: Join our developer community for help

### Common Issues
- **Broken Links**: Use relative paths for internal links
- **Image Display**: Store images in appropriate directories
- **Navigation**: Update index files when adding new pages
- **Formatting**: Use markdown preview to check formatting

## 🎉 Recognition

We appreciate all documentation contributions! Contributors will be:
- **Credited**: Listed in documentation contributors
- **Recognized**: Mentioned in release notes
- **Invited**: To join documentation maintainer team

---

**📝 Document Type**: Contributing Guidelines  
**📅 Last Updated**: December 9, 2025  
**✅ Status**: Current and Active  
**🔗 Related**: [README](../README.md) | [Documentation Index](./docs/README.md)