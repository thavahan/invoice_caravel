import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/shipment.dart';

/// Advanced PDF Service with intelligent N-page generation for invoice documents
///
/// Features:
/// - Multi-page pagination with intelligent item distribution
/// - Table 1: Itemized manifest (30 items first page, 40 items continuation pages)
/// - Table 2: Product type summary (separate page)
/// - Table 3: Product details by type (separate page)
/// - Professional formatting with company branding
/// - Automatic gross total calculation in words
///
/// Last Updated: December 23, 2025
/// Configuration: Optimized for A4 format with 20px margins
/// Font: Cambria regular/bold, Logo: Caravel_logo.png
///
/// Changelog:
/// - Dec 23, 2025: Removed continuation indicators, increased item limits (15→30, 20→40)
/// - Fixed space calculations, corrected _summaryHeight from 120px to 150px
/// - Enhanced debugging output for pagination analysis
/// - Improved item distribution logic for better space utilization
///
/// Technical Notes:
/// - A4 page height: 842px, available content space: ~652px
/// - Item row height: 12px, allows ~50+ items per page theoretically
/// - Current limits ensure professional appearance and readability
class PdfService {
  // Performance optimizations - load fonts once
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.MemoryImage? _logoImage;

  // Layout constants optimized for readability and professional appearance
  // Updated Dec 23, 2025 - Verified dimensions for proper space calculations
  static const double _pageMargin = 20.0;
  static const double _headerHeight = 100.0; // Compact header design
  static const double _footerHeight = 50.0;
  static const double _itemRowHeight = 12.0; // Each item row height
  static const double _summaryHeight =
      150.0; // Summary section height (corrected from 120px)
  static const double _tableHeaderHeight = 25.0;
  static const double _sectionSpacing = 8.0;

  // Multi-page configuration - Updated Dec 23, 2025
  // Current item limits: First page=30, Continuation pages=40
  // Total space available per page: ~652px (A4 minus margins/headers)
  static const int FORCE_MULTIPAGE_ITEM_COUNT =
      8; // Force multi-page when more than this many items
  static const int MAX_ITEMS_FIRST_PAGE =
      30; // Maximum items on page 1 with summary
  static const int MAX_ITEMS_CONTINUATION_PAGE =
      40; // Maximum items per continuation page
  static const int ITEMS_PER_TABLE_PAGE = 25; // Legacy constant for reference

  /// Main PDF generation method - Entry point for creating multi-page invoice PDFs
  ///
  /// Parameters:
  /// - [shipment]: Shipment data containing invoice details
  /// - [items]: List of invoice items for Table 1 (itemized manifest)
  /// - [masterProductTypes]: Master data for Table 3 (product type details)
  ///
  /// Returns: Displays PDF using system print dialog
  /// Throws: Exception if PDF generation fails
  Future<void> generateShipmentPDF(Shipment shipment, List<dynamic> items,
      List<dynamic> masterProductTypes) async {
    try {
      print('📄 Starting intelligent N-page PDF generation');

      // Load fonts efficiently
      _regularFont ??=
          await pw.Font.ttf(await rootBundle.load('fonts/Cambria.ttf'));
      _boldFont ??=
          await pw.Font.ttf(await rootBundle.load('fonts/cambriab.ttf'));

      // Load logo image efficiently
      _logoImage ??= pw.MemoryImage(
          (await rootBundle.load('asset/images/Caravel_logo.png'))
              .buffer
              .asUint8List());

      final pdf = pw.Document();

      print('📦 Processing ${items.length} items for shipment ${shipment.awb}');

      // DEBUG: Show what items we're working with
      print('📋 DEBUG: Items content:');
      for (int i = 0; i < items.length && i < 3; i++) {
        print('   Item $i: ${items[i]}');
      }
      if (items.length > 3) {
        print('   ... and ${items.length - 3} more items');
      }

      // Calculate optimal pagination strategy
      final paginationPlan =
          _calculateOptimalPagination(items, masterProductTypes);
      final totalPages = paginationPlan['totalPages'] as int;
      final pageLayouts =
          paginationPlan['layouts'] as List<Map<String, dynamic>>;

      print(
          '📄 Intelligent pagination: $totalPages pages using ${paginationPlan['strategy']} strategy');

      // Generate each page dynamically
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final layout = pageLayouts[pageIndex];
        print(
            '📄 Building page ${pageIndex + 1}/${totalPages}: ${layout['type']}');

        pdf.addPage(_buildDynamicPage(shipment, items, masterProductTypes,
            layout, pageIndex + 1, totalPages, _logoImage!));

        print('✅ Page ${pageIndex + 1} added successfully');
      }

      print('📄 Successfully generated $totalPages pages');
      await _outputPDF(pdf, shipment);
    } catch (e, stackTrace) {
      print('❌ PDF Generation Error: $e');
      print('📄 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Simplified pagination logic: Table1 -> Table2 -> Table3
  Map<String, dynamic> _calculateOptimalPagination(
      List<dynamic> items, List<dynamic> masterProductTypes) {
    print('🔍 Starting simplified pagination logic...');
    print('📊 Dataset size: ${items.length} items');

    // Calculate available space per page - A4 is ~842 points tall
    final double availablePerPage = PdfPageFormat.a4.height -
        (_pageMargin * 2) - // 40 total
        _headerHeight - // 100
        _footerHeight; // 50
    // = ~652 points available

    print(
        '📏 Available space per page: ${availablePerPage.toStringAsFixed(1)}px');
    print('📏 Item row height: $_itemRowHeight px');
    print('📏 Summary height: $_summaryHeight px');
    print('📏 Table header height: $_tableHeaderHeight px');

    List<Map<String, dynamic>> layouts = [];

    // STEP 1: Calculate Table 1 pages (starting from page 1 with summary)
    print('📄 Planning Table 1 distribution...');

    // Page 1: Summary + Table 1 start - realistic space calculation
    double firstPageSpace = availablePerPage -
        _summaryHeight -
        _sectionSpacing -
        _tableHeaderHeight;

    // Calculate realistic items per page - be conservative
    int maxItemsOnFirstPage = (firstPageSpace / _itemRowHeight).floor();

    // Cap at reasonable limits regardless of calculated space
    int itemsOnFirstPage =
        math.min(maxItemsOnFirstPage, 30); // Never more than 30 on first page
    itemsOnFirstPage = math.max(1, itemsOnFirstPage); // At least 1 item
    itemsOnFirstPage =
        math.min(itemsOnFirstPage, items.length); // Don't exceed total

    print(
        '📄 Page 1: Summary + ${itemsOnFirstPage} items (calculated from ${firstPageSpace.toStringAsFixed(1)}px space, max possible: ${maxItemsOnFirstPage}, capped at 30)');

    // Debug space calculations
    print('📐 Space calculation details:');
    print('   - Available per page: ${availablePerPage.toStringAsFixed(1)}px');
    print('   - Summary height: ${_summaryHeight}px');
    print('   - Section spacing: ${_sectionSpacing}px');
    print('   - Table header height: ${_tableHeaderHeight}px');
    print('   - First page space: ${firstPageSpace.toStringAsFixed(1)}px');
    print('   - Item row height: ${_itemRowHeight}px');
    print('   - Max items calculated: ${maxItemsOnFirstPage}');
    print('   - Items on first page (capped at 30): ${itemsOnFirstPage}');
    layouts.add({
      'type': 'summary_and_table1_start',
      'showSummary': true,
      'showTable1': true,
      'showTable2': false,
      'showTable3': false,
      'table1Start': 0,
      'table1End': itemsOnFirstPage,
    });

    int processedItems = itemsOnFirstPage;

    // Continue Table 1 on subsequent pages until ALL items are processed
    while (processedItems < items.length) {
      double pageSpace =
          availablePerPage - _tableHeaderHeight - _sectionSpacing;

      // Calculate realistic items per continuation page
      int maxItemsOnThisPage = (pageSpace / _itemRowHeight).floor();

      // Cap at reasonable limits - never more than 40 items per continuation page
      int itemsOnThisPage = math.min(maxItemsOnThisPage, 40);
      itemsOnThisPage = math.max(1, itemsOnThisPage); // At least 1 item

      // Don't exceed remaining items
      int remainingItems = items.length - processedItems;
      itemsOnThisPage = math.min(itemsOnThisPage, remainingItems);

      int endIndex = processedItems + itemsOnThisPage;
      print(
          '📄 Table 1 continuation: items ${processedItems + 1}-${endIndex} (${itemsOnThisPage} items, ${pageSpace.toStringAsFixed(1)}px space)');

      layouts.add({
        'type': 'table1_continuation',
        'showSummary': false,
        'showTable1': true,
        'showTable2': false,
        'showTable3': false,
        'table1Start': processedItems,
        'table1End': endIndex,
      });

      processedItems = endIndex;

      // Safety check to prevent infinite loops
      if (processedItems >= items.length) {
        break;
      }
    }

    print(
        '📄 ✅ All ${items.length} items distributed across ${layouts.length} Table 1 pages');

    // STEP 2: Add Table 2 (after ALL Table 1 items are complete)
    print('📄 Adding Table 2 after Table 1 completion');

    // For simplicity, always put Table 2 on its own page to avoid space calculation issues
    print('📄 Adding Table 2 on separate page for reliability');
    layouts.add({
      'type': 'table2_only',
      'showSummary': false,
      'showTable1': false,
      'showTable2': true,
      'showTable3': false,
      'table1Start': 0,
      'table1End': 0,
    });

    // STEP 3: Always add Table 3 as final page
    print('📄 Adding Table 3 as final page');
    layouts.add({
      'type': 'table3_only',
      'showSummary': false,
      'showTable1': false,
      'showTable2': false,
      'showTable3': true,
      'table1Start': 0,
      'table1End': 0,
    });

    print('📋 Final pagination plan: ${layouts.length} pages total');
    for (int i = 0; i < layouts.length; i++) {
      final layout = layouts[i];
      final start = layout['table1Start'] ?? 0;
      final end = layout['table1End'] ?? 0;
      final itemCount = end - start;
      print(
          '   Page ${i + 1}: ${layout['type']} ${itemCount > 0 ? '($itemCount items: ${start + 1}-$end)' : '(no Table 1 items)'}');
    }

    return {
      'totalPages': layouts.length,
      'layouts': layouts,
      'strategy': 'sequential_table_flow',
      'itemsPerPage': 'variable',
    };
  }

  /// Build a dynamic page based on layout configuration
  pw.Page _buildDynamicPage(
      Shipment shipment,
      List<dynamic> items,
      List<dynamic> masterProductTypes,
      Map<String, dynamic> layout,
      int pageNumber,
      int totalPages,
      pw.ImageProvider logoImage) {
    return pw.Page(
      margin: const pw.EdgeInsets.all(_pageMargin),
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Page header
            _buildAdvancedHeader(
                shipment, pageNumber, totalPages, layout['type'], logoImage),
            pw.SizedBox(height: 8),

            // Dynamic content based on layout
            ...(_buildPageContent(shipment, items, masterProductTypes, layout,
                pageNumber, totalPages)),

            pw.Spacer(),

            // Page footer
            _buildAdvancedFooter(
                pageNumber, totalPages, layout['type'], items.length),
          ],
        );
      },
    );
  }

  /// Build advanced page header
  pw.Widget _buildAdvancedHeader(Shipment shipment, int pageNumber,
      int totalPages, String pageType, pw.ImageProvider logoImage) {
    // Debug: Check shipment data
    print('📄 Building header for page $pageNumber');
    print('📄 Invoice Number: "${shipment.invoiceNumber}"');
    print('📄 Invoice Date: ${shipment.invoiceDate}');
    if (shipment.invoiceDate != null) {
      print(
          '📄 Formatted Date: ${DateFormat('dd MMM yyyy').format(shipment.invoiceDate!)}');
    }

    return pw.Container(
      width: double.infinity,
      height: _headerHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(width: 0.4, color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          // INVOICE title at the top - more compact
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(2),
                topRight: pw.Radius.circular(2),
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                pageType == 'table3_only' ? 'Flower List' : 'INVOICE',
                style: pw.TextStyle(
                  font: _boldFont!,
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          // Main header content below
          pw.Expanded(
            child: pw.Row(
              children: [
                // Logo section
                pw.Container(
                  width: 80,
                  padding: pw.EdgeInsets.all(5),
                  child: pw.Image(
                    logoImage,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                // Left side - Title and description
                pw.Expanded(
                  flex: 3,
                  child: pw.Padding(
                    padding: pw.EdgeInsets.all(15),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('Caravel Solution Pvt ltd',
                            style: pw.TextStyle(
                                font: _boldFont!,
                                fontSize: 16,
                                color: PdfColors.blue800)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                            '741/19 Thiruvengadam Salai,Sankarankoil,\nTirunelveli,Tamilnadu,627556',
                            style: pw.TextStyle(
                                font: _regularFont!,
                                fontSize: 10,
                                color: PdfColors.blue600)),
                      ],
                    ),
                  ),
                ),
                // Right side - Invoice details and page info
                pw.Container(
                  width: 180, // Fixed width to ensure visibility
                  padding: pw.EdgeInsets.all(8),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw
                        .CrossAxisAlignment.start, // Changed from end to start
                    children: [
                      pw.Container(
                        width: double.infinity, // Take full width of parent
                        padding: pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                'Invoice No     : ${shipment.invoiceNumber.isNotEmpty ? shipment.invoiceNumber : ''}',
                                style: pw.TextStyle(
                                    font: _boldFont!, fontSize: 10)),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Invoice Date : ${shipment.invoiceDate != null ? DateFormat('dd MMM yyyy').format(shipment.invoiceDate!) : 'Not set'}',
                              style:
                                  pw.TextStyle(font: _boldFont!, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build dynamic page content based on layout
  List<pw.Widget> _buildPageContent(
      Shipment shipment,
      List<dynamic> items,
      List<dynamic> masterProductTypes,
      Map<String, dynamic> layout,
      int pageNumber,
      int totalPages) {
    List<pw.Widget> content = [];

    print('📄 Building page $pageNumber/${totalPages} with layout: $layout');

    // Add invoice summary if required
    if (layout['showSummary'] == true) {
      print('📄 Adding summary to page $pageNumber');
      content.addAll(_buildInvoiceSummary(shipment, items));
    }

    // Add spacing between sections
    if (content.isNotEmpty) {
      content.add(pw.SizedBox(height: _sectionSpacing));
    }

    // Add Table 1 if required
    if (layout['showTable1'] == true) {
      final int startIdx = layout['table1Start'] ?? 0;
      final int endIdx = layout['table1End'] ?? items.length;
      print(
          '📄 Adding Table 1 to page $pageNumber: items ${startIdx + 1}-$endIdx');
      content.addAll(_buildTable1(
          shipment, items, startIdx, endIdx, pageNumber, totalPages));
    }

    // Add spacing between tables
    if (layout['showTable1'] == true && layout['showTable2'] == true) {
      content.add(pw.SizedBox(height: _sectionSpacing));
    }

    // Add Table 2 if required
    if (layout['showTable2'] == true) {
      print('📄 Adding Table 2 (product summary) to page $pageNumber');
      try {
        final table2Widgets = _buildTable2(shipment, items);
        if (table2Widgets.isNotEmpty) {
          content.addAll(table2Widgets);
          print(
              '✅ Product summary table added successfully with ${table2Widgets.length} widgets');
        } else {
          print('⚠️ Product summary table is empty - no widgets returned');
        }
      } catch (e) {
        print('❌ Error building Table 2: $e');
        // Add placeholder if error occurs
        content.add(pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('Error loading product summary: $e',
                style: pw.TextStyle(
                    font: _regularFont!, fontSize: 8, color: PdfColors.red))));
      }
    }

    // Add Table 3 if required
    if (layout['showTable3'] == true) {
      print('📄 Adding Table 3 (product type details) to page $pageNumber');
      // Add shipment information section for Table 3 page
      content.addAll(_buildInvoiceSummary(shipment, items));
      content.add(pw.SizedBox(height: _sectionSpacing));
      try {
        final table3Widgets = _buildTable3(masterProductTypes, items);
        if (table3Widgets.isNotEmpty) {
          content.addAll(table3Widgets);
          print(
              '✅ Product type details table added successfully with ${table3Widgets.length} widgets');
        } else {
          print('⚠️ Product type details table is empty - no widgets returned');
        }
      } catch (e) {
        print('❌ Error building Table 3: $e');
        // Add placeholder if error occurs
        content.add(pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('Error loading product type details: $e',
                style: pw.TextStyle(
                    font: _regularFont!, fontSize: 8, color: PdfColors.red))));
      }
    }

    // Add Gross Total in words if Table 2 is shown (final page or single page)
    if (layout['showTable2'] == true) {
      print('📄 Adding Gross Total to page $pageNumber');
      final totalAmount = _calculateProductSummary(items)['total'] as double;
      content.add(pw.SizedBox(height: _sectionSpacing));
      content.add(_buildGrossTotalInWords(totalAmount));
    }

    print('📄 Page $pageNumber content built: ${content.length} widgets');
    return content;
  }

  /// Build comprehensive invoice summary
  List<pw.Widget> _buildInvoiceSummary(Shipment shipment, List<dynamic> items) {
    return [
      // Invoice and Tax Details Row
      // pw.Row(
      //   crossAxisAlignment: pw.CrossAxisAlignment.start,
      //   children: [
      //     pw.Expanded(
      //       child: pw.Container(
      //         padding: pw.EdgeInsets.all(15),
      //         decoration: pw.BoxDecoration(
      //           border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
      //           borderRadius: pw.BorderRadius.circular(5),
      //         ),
      //         child: pw.Column(
      //           crossAxisAlignment: pw.CrossAxisAlignment.start,
      //           children: [
      //             pw.Text('INVOICE DETAILS',
      //                 style: pw.TextStyle(
      //                     font: _boldFont!,
      //                     fontSize: 12,
      //                     color: PdfColors.blue800)),
      //             pw.SizedBox(height: 10),
      //             _buildDetailRow('Invoice Number:', shipment.invoiceNumber),
      //             _buildDetailRow('AWB Number:', shipment.awb),
      //             _buildDetailRow('Status:', shipment.status.toUpperCase()),
      //             _buildDetailRow(
      //                 'Invoice Date:',
      //                 shipment.invoiceDate != null
      //                     ? _formatDate(shipment.invoiceDate!)
      //                     : 'N/A'),
      //           ],
      //         ),
      //       ),
      //     ),
      //     pw.SizedBox(width: 15),
      //     pw.Expanded(
      //       child: pw.Container(
      //         padding: pw.EdgeInsets.all(15),
      //         decoration: pw.BoxDecoration(
      //           border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
      //           borderRadius: pw.BorderRadius.circular(5),
      //         ),
      //         child: pw.Column(
      //           crossAxisAlignment: pw.CrossAxisAlignment.start,
      //           children: [
      //             pw.Text('TAX & REGISTRATION',
      //                 style: pw.TextStyle(
      //                     font: _boldFont!,
      //                     fontSize: 12,
      //                     color: PdfColors.blue800)),
      //             pw.SizedBox(height: 10),
      //             _buildDetailRow('SGST Number:',
      //                 shipment.sgstNo.isEmpty ? 'N/A' : shipment.sgstNo),
      //             _buildDetailRow('IEC Code:',
      //                 shipment.iecCode.isEmpty ? 'N/A' : shipment.iecCode),
      //             _buildDetailRow(
      //                 'Place of Receipt:',
      //                 shipment.placeOfReceipt.isEmpty
      //                     ? 'N/A'
      //                     : shipment.placeOfReceipt),
      //             _buildDetailRow(
      //                 'Freight Terms:',
      //                 shipment.freightTerms.isEmpty
      //                     ? 'N/A'
      //                     : shipment.freightTerms),
      //           ],
      //         ),
      //       ),
      //     ),
      //   ],
      // ),

      // pw.SizedBox(height: 20),

      // Shipment Information and Consignee Row - Merged into single container
      pw.Container(
        width: double.infinity,
        height:
            140, // Increased from 200 to accommodate all content including consignee details
        padding: pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.purple600),
          borderRadius: pw.BorderRadius.circular(5),
          color: PdfColors.purple50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Shipment Information Section
            pw.Text('SHIPMENT INFORMATION',
                style: pw.TextStyle(
                    font: _boldFont!,
                    fontSize: 12,
                    color: PdfColors.purple800)),
            pw.SizedBox(height: 8),

            // First row - Three columns layout
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // First column
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('AWB No',
                          shipment.awb.isNotEmpty ? shipment.awb : ''),
                      _buildDetailRow(
                          'Master AWB',
                          shipment.masterAwb.isNotEmpty
                              ? shipment.masterAwb
                              : ''),
                      _buildDetailRow(
                          'House AWB',
                          shipment.houseAwb.isNotEmpty
                              ? shipment.houseAwb
                              : ''),
                      _buildDetailRow(
                          'Place of Receipt',
                          shipment.placeOfReceipt.isNotEmpty
                              ? shipment.placeOfReceipt
                              : ''),
                      _buildDetailRow('Place of Delivery',
                          '${shipment.destination.isNotEmpty ? shipment.destination : ''}'),
                      _buildDetailRow(
                          'Bill To',
                          shipment.consignee.isNotEmpty
                              ? shipment.consignee
                              : ''),
                    ],
                  ),
                ),
                pw.SizedBox(width: 15),
                // Second column
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Flight No & Date',
                          shipment.flightDate != null
                              ? '${shipment.flightNo} - ${_formatDate(shipment.flightDate!)}'
                              : shipment.flightNo),
                      _buildDetailRow('AirPort Of Departure',
                          '${shipment.origin.isNotEmpty ? shipment.origin : ''}'),
                      _buildDetailRow('AirPort of Discharge',
                          '${shipment.destination.isNotEmpty ? shipment.destination : ''}'),
                      _buildDetailRow(
                          'ETA into "${shipment.destination.isNotEmpty ? shipment.destination : ''}"',
                          _formatDate(shipment.eta)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 15),
                // Third column
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Date of Issue',
                          shipment.dateOfIssue != null
                              ? _formatDate(shipment.dateOfIssue!)
                              : ''),
                      _buildDetailRow('Issued At',
                          shipment.origin.isNotEmpty ? shipment.origin : ''),
                      _buildDetailRow('Freight Terms',
                          '${shipment.freightTerms.isNotEmpty ? shipment.freightTerms : ''}'),
                      _buildDetailRow(
                          'Consignee',
                          shipment.consignee.isNotEmpty
                              ? shipment.consignee
                              : ''),
                      _buildDetailRow(
                          'Address',
                          shipment.consigneeAddress.isNotEmpty
                              ? shipment.consigneeAddress
                              : ''),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 10),

            // Second row - Client Reference spanning full width
            _buildDetailRow('Client Reference',
                shipment.clientRef.isNotEmpty ? shipment.clientRef : ''),
          ],
        ),
      ),
    ];
  }

  /// Helper to build detail rows
  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60, // Fixed width for label area
            child: pw.Text(label,
                style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
          ),
          pw.Text(': ', style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    font: label == 'Consignee' ? _boldFont! : _regularFont!,
                    fontSize: 8)),
          ),
        ],
      ),
    );
  }

  /// Build Table 1 - Itemized Manifest with pagination support
  List<pw.Widget> _buildTable1(Shipment shipment, List<dynamic> items,
      int startIndex, int endIndex, int currentPage, int totalPages) {
    print(
        '🔧 Building Table 1: startIndex=$startIndex, endIndex=$endIndex, total=${items.length}');

    if (startIndex >= items.length || endIndex <= startIndex) {
      print(
          '❌ Invalid indices for Table 1: start=$startIndex, end=$endIndex, total=${items.length}');
      return [
        pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('No items to display - Invalid range',
                style: pw.TextStyle(
                    font: _regularFont!, fontSize: 10, color: PdfColors.red)))
      ];
    }

    // Ensure we don't go beyond array bounds
    final safeEndIndex = math.min(endIndex, items.length);
    final itemsToShow = items.sublist(startIndex, safeEndIndex);
    print(
        '📦 Table 1 will show ${itemsToShow.length} items (items ${startIndex + 1} to ${safeEndIndex})');

    // Log first few items for debugging
    for (int i = 0; i < math.min(3, itemsToShow.length); i++) {
      final item = itemsToShow[i];
      final type = _getItemValue(item, 'type', 'UNKNOWN');
      final weight = _getItemValue(item, 'weight', '0');
      print('   📦 Item ${i + 1}: type="$type", weight="$weight"');
    }

    // Calculate total unique boxes
    Set<String> uniqueBoxes = {};
    for (var item in items) {
      String boxNumber = _getItemValue(item, 'boxNumber', '');
      if (boxNumber.isNotEmpty) {
        uniqueBoxes.add(boxNumber);
      }
    }
    int totalBoxes = uniqueBoxes.length;

    return [
      // Table header with pagination info
      pw.SizedBox(height: 8),
      pw.Container(
        padding: pw.EdgeInsets.all(5), // Reduced from 8
        decoration: pw.BoxDecoration(
          color: PdfColors.blue800,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(5),
            topRight: pw.Radius.circular(5),
          ),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              children: [
                pw.Text('ITEMIZED MANIFEST',
                    style: pw.TextStyle(
                        font: _boldFont!,
                        fontSize: 10,
                        color: PdfColors.white)), // Reduced from 12
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // if (totalPages > 1)
                    //   pw.Container(
                    //     padding:
                    //         pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    //     decoration: pw.BoxDecoration(
                    //       color: PdfColors.white.shade(0.2),
                    //       borderRadius: pw.BorderRadius.circular(3),
                    //     ),
                    //     child: pw.Text(
                    //         'Items ${startIndex + 1}-$endIndex of ${items.length}',
                    //         style: pw.TextStyle(
                    //             font: _boldFont!,
                    //             fontSize: 8,
                    //             color: PdfColors.white)),
                    //   ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('No. & Kind of Pkgs ',
                            style: pw.TextStyle(
                                font: _boldFont!,
                                fontSize: 8,
                                color: PdfColors.white)),
                        pw.Container(
                          width: 30,
                          height: 14,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white.shade(0.2),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            '$totalBoxes',
                            style: pw.TextStyle(
                                font: _boldFont!,
                                fontSize: 8,
                                color: PdfColors.black),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text('Gross weight(kg) ',
                            style: pw.TextStyle(
                                font: _boldFont!,
                                fontSize: 8,
                                color: PdfColors.white)),
                        pw.Container(
                          width: 45, // Width to fit "0000.00"
                          height: 14, // Height to fit the text
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(
                                width: 0.5, color: PdfColors.grey600),
                          ),
                          child: pw.Text(
                              shipment.grossWeight.toStringAsFixed(2),
                              style: pw.TextStyle(
                                  font: _boldFont!,
                                  fontSize: 8,
                                  color: PdfColors.black),
                              textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),

      // Column headers
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(1), // Box No. - 10%
            1: pw.FlexColumnWidth(8), // Item Description - 80%
            2: pw.FlexColumnWidth(1), // Weight - 10%
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: [
            pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableHeader('Box No.'),
                  _buildTableHeader('Item Description'),
                  _buildTableHeader('Weight (kg)'),
                ]),
          ],
        ),
      ),

      // Data rows
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
          ),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(8),
            2: pw.FlexColumnWidth(1),
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: _buildTable1Rows(itemsToShow, startIndex),
        ),
      ),
    ];
  }

  /// Build Table 1 data rows with smart box grouping
  List<pw.TableRow> _buildTable1Rows(List<dynamic> items, int baseIndex) {
    List<pw.TableRow> rows = [];
    String? previousBoxNumber;

    print(
        '🔨 Building ${items.length} rows for Table 1 (baseIndex: $baseIndex)');

    if (items.isEmpty) {
      print('⚠️ WARNING: No items to build rows for!');
      return [
        pw.TableRow(children: [
          pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('No data available',
                  style: pw.TextStyle(font: _regularFont!, fontSize: 8))),
          pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('No items in range',
                  style: pw.TextStyle(font: _regularFont!, fontSize: 8))),
          pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text('0.00',
                  style: pw.TextStyle(font: _regularFont!, fontSize: 8))),
        ])
      ];
    }

    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      final weight = double.tryParse(_getItemValue(item, 'weight', '0')) ?? 0.0;
      String currentBoxNumber =
          _getItemValue(item, 'boxNumber', 'Box ${baseIndex + index + 1}');

      String itemType = _getItemValue(item, 'type', 'UNKNOWN');
      if (index < 5) {
        // Show details for first 5 items only
        print(
            '   Row ${index + 1}: type="$itemType", weight=$weight, box="$currentBoxNumber"');
      }

      // Smart box number display
      String displayBoxNumber = '';
      if (currentBoxNumber != previousBoxNumber) {
        displayBoxNumber = currentBoxNumber;
        previousBoxNumber = currentBoxNumber;
      }

      // Create table row - simplified to avoid errors
      rows.add(
        pw.TableRow(
            decoration: index % 2 == 0
                ? pw.BoxDecoration(color: PdfColors.grey50)
                : null,
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(displayBoxNumber,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(_formatItemDescription(item, weight),
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(weight.toStringAsFixed(2),
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
            ]),
      );
    }

    print('✅ Built ${rows.length} rows for Table 1');
    return rows;
  }

  /// Calculate product summary and grand total amount from items
  Map<String, dynamic> _calculateProductSummary(List<dynamic> items) {
    try {
      Map<String, Map<String, dynamic>> productSummary = {};

      print('📦 Calculating product summary for ${items.length} items');
      for (int i = 0; i < items.length && i < 3; i++) {
        print('   Item $i: ${items[i]}');
      }

      for (final item in items) {
        String productType =
            _getItemValue(item, 'type', 'UNKNOWN').toUpperCase();
        double weight =
            double.tryParse(_getItemValue(item, 'weight', '0')) ?? 0.0;
        double rate = double.tryParse(_getItemValue(item, 'rate', '0')) ?? 0.0;
        int approxQuantity =
            int.tryParse(_getItemValue(item, 'approxQuantity', '0')) ?? 0;

        print(
            '   Processing: productType="$productType", weight=$weight, rate=$rate, approxQty=$approxQuantity');

        if (productSummary.containsKey(productType)) {
          productSummary[productType]!['totalWeight'] =
              (productSummary[productType]!['totalWeight'] ?? 0.0) + weight;
          productSummary[productType]!['totalAmount'] =
              (productSummary[productType]!['totalAmount'] ?? 0.0) +
                  (weight * rate);
          productSummary[productType]!['totalApproxQuantity'] =
              (productSummary[productType]!['totalApproxQuantity'] ?? 0) +
                  approxQuantity;
        } else {
          productSummary[productType] = {
            'rate': rate,
            'totalWeight': weight,
            'totalAmount': weight * rate,
            'totalApproxQuantity': approxQuantity,
          };
        }
      }

      double grandTotalAmount = 0.0;
      for (var summary in productSummary.values) {
        grandTotalAmount += summary['totalAmount'] ?? 0.0;
      }

      print(
          '📦 Product summary calculated: ${productSummary.length} types, total \$${grandTotalAmount.toStringAsFixed(2)}');

      return {
        'summary': productSummary,
        'total': grandTotalAmount,
      };
    } catch (e) {
      print('❌ Error calculating flower summary: $e');
      return {
        'summary': <String, Map<String, double>>{},
        'total': 0.0,
      };
    }
  }

  /// Build Table 2 - Product Type Summary
  List<pw.Widget> _buildTable2(Shipment shipment, List<dynamic> items) {
    final summaryData = _calculateProductSummary(items);
    final productSummary =
        summaryData['summary'] as Map<String, Map<String, dynamic>>;
    final grandTotalAmount = summaryData['total'] as double;

    var sortedTypes = productSummary.keys.toList()..sort();
    double grandTotalWeight = 0.0;
    int grandTotalApproxQuantity = 0;

    print(
        '📦 Building product summary table with ${sortedTypes.length} product types');
    if (sortedTypes.isEmpty) {
      print(
          '⚠️ WARNING: No product types found in summary! Returning empty table.');
      return [
        pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('No product type data available',
                style: pw.TextStyle(
                    font: _regularFont!,
                    fontSize: 10,
                    color: PdfColors.grey700)))
      ];
    }
    for (var type in sortedTypes) {
      print(
          '   ✓ $type: ${productSummary[type]!['totalWeight']}kg @ \$${productSummary[type]!['rate']} = \$${productSummary[type]!['totalAmount']}');
    }

    List<pw.TableRow> rows = [];

    // Build data rows
    for (int index = 0; index < sortedTypes.length; index++) {
      String productType = sortedTypes[index];
      var summary = productSummary[productType]!;

      double totalWeight = summary['totalWeight'] ?? 0.0;
      double rate = summary['rate'] ?? 0.0;
      double totalAmount = summary['totalAmount'] ?? 0.0;
      int totalApproxQuantity = (summary['totalApproxQuantity'] ?? 0).toInt();

      grandTotalWeight += totalWeight;
      grandTotalApproxQuantity += totalApproxQuantity;

      rows.add(
        pw.TableRow(
            decoration: index % 2 == 0
                ? pw.BoxDecoration(color: PdfColors.grey50)
                : null,
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(productType,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text('$totalApproxQuantity',
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text('\$${rate.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text('${totalWeight.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text('\$${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: _boldFont!, fontSize: 7),
                    textAlign: pw.TextAlign.right),
              ),
            ]),
      );
    }

    // Add totals row
    rows.add(
      pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text('GRAND TOTAL',
                  style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text('$grandTotalApproxQuantity',
                  style: pw.TextStyle(font: _boldFont!, fontSize: 8),
                  textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text('',
                  style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text('${grandTotalWeight.toStringAsFixed(2)}',
                  style: pw.TextStyle(font: _boldFont!, fontSize: 8),
                  textAlign: pw.TextAlign.center),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(4),
              child: pw.Text('\$${grandTotalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      font: _boldFont!, fontSize: 8, color: PdfColors.blue800),
                  textAlign: pw.TextAlign.right),
            ),
          ]),
    );

    return [
      // Table header
      pw.Container(
        padding: pw.EdgeInsets.all(5), // Reduced from 8
        decoration: pw.BoxDecoration(
          color: PdfColors.blue800,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(5),
            topRight: pw.Radius.circular(5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SUMMARY BY FLOWER TYPE',
                style: pw.TextStyle(
                    font: _boldFont!,
                    fontSize: 10,
                    color: PdfColors.white)), // Reduced from 12
          ],
        ),
      ),

      // Column headers
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(2.5), // TYPE - reduced from 3
            1: pw.FlexColumnWidth(1.5), // RATE - reduced from 2
            2: pw.FlexColumnWidth(1.5), // WEIGHT - reduced from 2
            3: pw.FlexColumnWidth(2), // APPROX.QTY - new column
            4: pw.FlexColumnWidth(2.5), // AMOUNT - reduced from 3
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: [
            pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableHeader('TYPE'),
                  _buildTableHeader('APPROX.QTY'),
                  _buildTableHeader('RATE'),
                  _buildTableHeader('WEIGHT'),
                  _buildTableHeader('AMOUNT'),
                ]),
          ],
        ),
      ),

      // Data table
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
          ),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(2.5), // TYPE - reduced from 3
            1: pw.FlexColumnWidth(1.5), // RATE - reduced from 2
            2: pw.FlexColumnWidth(1.5), // WEIGHT - reduced from 2
            3: pw.FlexColumnWidth(2), // APPROX.QTY - new column
            4: pw.FlexColumnWidth(2.5), // AMOUNT - reduced from 3
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: rows,
        ),
      ),
    ];
  }

  /// Build Table 3 - Product Type Details
  List<pw.Widget> _buildTable3(
      List<dynamic> masterProductTypes, List<dynamic> items) {
    print(
        '📊 Building product summary by product type table for shipment items');

    // Extract unique product types used in this shipment (use 'type' field like Table 2)
    Set<String> usedProductTypes = {};
    for (final item in items) {
      String productType = _getItemValue(item, 'type', 'UNKNOWN').trim();
      if (productType.isNotEmpty && productType != 'UNKNOWN') {
        usedProductTypes.add(productType.toUpperCase());
      }
    }

    print(
        '📋 Found ${usedProductTypes.length} unique product types in shipment: ${usedProductTypes.join(', ')}');

    // Filter master product types to only include those used in shipment
    List<Map<String, dynamic>> filteredProductTypes = [];
    for (final masterType in masterProductTypes) {
      final masterTypeMap = masterType as Map<String, dynamic>;
      final masterName =
          (masterTypeMap['name'] ?? masterTypeMap['flower_name'] ?? '')
              .toString()
              .toUpperCase()
              .trim();

      if (usedProductTypes.contains(masterName)) {
        filteredProductTypes.add(masterTypeMap);
      }
    }

    print(
        '✅ Filtered to ${filteredProductTypes.length} relevant product types for this shipment');

    if (filteredProductTypes.isEmpty) {
      print(
          '⚠️ WARNING: No matching product types found in master data for this shipment!');
      return [
        pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text('No product type data available for this shipment',
                style: pw.TextStyle(
                    font: _regularFont!,
                    fontSize: 10,
                    color: PdfColors.grey700)))
      ];
    }

    List<pw.TableRow> rows = [];

    // Build data rows
    for (int index = 0; index < filteredProductTypes.length; index++) {
      var flowerType = filteredProductTypes[index];

      String category = flowerType['category'] ?? '';
      String commonName = flowerType['name'] ?? flowerType['flower_name'] ?? '';
      String genusSpecies = flowerType['genus_species_name'] ?? '';
      String plantFamily = flowerType['plant_family_name'] ?? '';
      String countryOfOrigin = flowerType['country_of_origin'] ?? '';

      rows.add(
        pw.TableRow(
            decoration: index % 2 == 0
                ? pw.BoxDecoration(color: PdfColors.grey50)
                : null,
            children: [
              // No (Auto increment)
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text('${index + 1}',
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7),
                    textAlign: pw.TextAlign.center),
              ),
              // Category
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(category,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              // Flower Common Name
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(commonName,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              // Genus/Species Name
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(genusSpecies,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              // Plant/Family Name
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(plantFamily,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
              // Country of Origin
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(countryOfOrigin,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
              ),
            ]),
      );
    }

    return [
      // Table header
      // pw.Container(
      //   padding: pw.EdgeInsets.all(5),
      //   decoration: pw.BoxDecoration(
      //     color: PdfColors.green800,
      //     borderRadius: pw.BorderRadius.only(
      //       topLeft: pw.Radius.circular(5),
      //       topRight: pw.Radius.circular(5),
      //     ),
      //   ),
      //   child: pw.Row(
      //     mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      //     children: [
      //       pw.Text('PRODUCT SUMMARY BY PRODUCT TYPE',
      //           style: pw.TextStyle(
      //               font: _boldFont!,
      //               fontSize: 10,
      //               color: PdfColors.white)),
      //     ],
      //   ),
      // ),

      // Column headers
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5, color: PdfColors.grey600),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(0.8), // No
            1: pw.FlexColumnWidth(1.5), // Category
            2: pw.FlexColumnWidth(2.5), // Flower Common Name
            3: pw.FlexColumnWidth(2.5), // Genus/Species Name
            4: pw.FlexColumnWidth(2.5), // Plant/Family Name
            5: pw.FlexColumnWidth(2), // Country of Origin
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: [
            pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableHeader('No'),
                  _buildTableHeader('Category'),
                  _buildTableHeader('Flower Common Name'),
                  _buildTableHeader('Genus/Species Name'),
                  _buildTableHeader('Plant/Family Name'),
                  _buildTableHeader('Country of Origin'),
                ]),
          ],
        ),
      ),

      // Data table
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            right: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
          ),
        ),
        child: pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(0.8), // No
            1: pw.FlexColumnWidth(1.5), // Category
            2: pw.FlexColumnWidth(2.5), // Flower Common Name
            3: pw.FlexColumnWidth(2.5), // Genus/Species Name
            4: pw.FlexColumnWidth(2.5), // Plant/Family Name
            5: pw.FlexColumnWidth(2), // Country of Origin
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: rows,
        ),
      ),
    ];
  }

  /// Build Gross Total in words
  pw.Widget _buildGrossTotalInWords(double amount) {
    print('🧾 Building Gross Total in words: $amount');
    String amountInWords = _numberToWords(amount);
    print('🧾 Amount in words: $amountInWords');
    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(
        'Gross Total (in words): $amountInWords ONLY',
        style: pw.TextStyle(
          font: _boldFont!,
          fontSize: 9,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Convert number to words
  String _numberToWords(double amount) {
    int dollars = amount.floor();
    int cents = ((amount - dollars) * 100).round();

    String dollarsWords = _convertToWords(dollars);
    String centsWords = _convertToWords(cents);

    String result = dollarsWords.isNotEmpty ? '$dollarsWords DOLLARS' : '';
    if (cents > 0) {
      result += dollarsWords.isNotEmpty ? ' AND ' : '';
      result += '$centsWords CENTS';
    }

    return result.isNotEmpty ? result : 'ZERO DOLLARS';
  }

  /// Helper to convert integer to words
  String _convertToWords(int number) {
    if (number == 0) return '';

    const List<String> units = [
      '',
      'ONE',
      'TWO',
      'THREE',
      'FOUR',
      'FIVE',
      'SIX',
      'SEVEN',
      'EIGHT',
      'NINE'
    ];
    const List<String> teens = [
      'TEN',
      'ELEVEN',
      'TWELVE',
      'THIRTEEN',
      'FOURTEEN',
      'FIFTEEN',
      'SIXTEEN',
      'SEVENTEEN',
      'EIGHTEEN',
      'NINETEEN'
    ];
    const List<String> tens = [
      '',
      '',
      'TWENTY',
      'THIRTY',
      'FORTY',
      'FIFTY',
      'SIXTY',
      'SEVENTY',
      'EIGHTY',
      'NINETY'
    ];

    String result = '';

    if (number >= 100) {
      result += '${units[number ~/ 100]} HUNDRED ';
      number %= 100;
    }

    if (number >= 20) {
      result += '${tens[number ~/ 10]} ';
      number %= 10;
    } else if (number >= 10) {
      result += '${teens[number - 10]} ';
      number = 0;
    }

    if (number > 0) {
      result += '${units[number]} ';
    }

    return result.trim();
  }

  /// Build advanced page footer with contextual information
  pw.Widget _buildAdvancedFooter(
      int pageNumber, int totalPages, String pageType, int totalItems) {
    String pageDescription = _getPageDescription(pageType, totalItems);

    return pw.Container(
      padding: pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(width: 1, color: PdfColors.blue800)),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$pageDescription - Page $pageNumber of $totalPages',
                    style: pw.TextStyle(
                        font: _boldFont!,
                        fontSize: 4,
                        color: PdfColors.grey700)),
                pw.Text('Advanced N-Page Invoice Generator v1.0',
                    style: pw.TextStyle(
                        font: _regularFont!,
                        fontSize: 4,
                        color: PdfColors.grey500)),
              ],
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text('Generated: ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(
                    font: _regularFont!,
                    fontSize: 8,
                    color: PdfColors.blue800)),
          ),
        ],
      ),
    );
  }

  /// Get page description for footer
  String _getPageDescription(String pageType, int totalItems) {
    switch (pageType) {
      case 'summary_and_table1_start':
        return 'Invoice Summary & Itemized Manifest';
      case 'table1_continuation':
        return 'Itemized Manifest (Continued)';
      case 'table1_final_and_table2':
        return 'Itemized Manifest (Final) & Product Summary';
      case 'table2_only':
        return 'Product Type Summary';
      case 'table3_only':
        return 'Product Summary by Product Type';
      default:
        return 'Invoice Document';
    }
  }

  /// Output PDF with proper error handling
  Future<void> _outputPDF(pw.Document pdf, Shipment shipment) async {
    try {
      print('📄 Showing PDF preview...');
      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: '${shipment.invoiceNumber}.pdf');
      print('📄 PDF preview shown successfully');
    } catch (e) {
      print('❌ PDF Output Error: $e');
      rethrow;
    }
  }

  /// Helper to build table headers
  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(font: _boldFont!, fontSize: 8),
          textAlign: pw.TextAlign.center),
    );
  }

  /// Format item description in the required format
  String _formatItemDescription(dynamic item, double weight) {
    String type = _getItemValue(item, 'type', 'UNKNOWN').toUpperCase();

    // Construct description from individual fields
    String flowerType = _getItemValue(item, 'flowerType', 'LOOSE FLOWERS');
    bool hasStems = item is Map ? (item['hasStems'] ?? false) : false;
    int approxQuantity =
        item is Map ? ((item['approxQuantity'] as num?)?.toInt() ?? 0) : 0;

    String stemsText = hasStems ? '' : 'NO STEMS';
    String description =
        '$flowerType${stemsText.isNotEmpty ? ', $stemsText' : ''}, APPROX $approxQuantity NOS';

    // Format: "JASMIN - 6.7 KG (TIED GARLANDS, NO STEMS, APPROX 6240 NOS)"
    String formattedDescription =
        '$type - ${weight.toStringAsFixed(1)} KG ($description)';

    return formattedDescription;
  }

  /// Helper to safely get item values
  String _getItemValue(dynamic item, String key, String fallback) {
    if (item is Map) {
      return (item[key] ?? fallback).toString();
    } else {
      try {
        final dynamic obj = item as dynamic;
        switch (key) {
          case 'type':
            return (obj.type ?? fallback).toString();
          case 'weight':
            return (obj.weight ?? fallback).toString();
          case 'description':
            return (obj.description ?? fallback).toString();
          case 'rate':
            return (obj.rate ?? fallback).toString();
          case 'boxNumber':
            return (obj.boxNumber ?? fallback).toString();
          case 'flowerType':
            return (obj.flowerType ?? fallback).toString();
          default:
            return fallback;
        }
      } catch (e) {
        return fallback;
      }
    }
  }

  /// Format date helper
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
