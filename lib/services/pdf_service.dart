import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as Math;
import 'package:intl/intl.dart';
import '../models/shipment.dart';

/// Advanced PDF Service with intelligent N-page generation
/// Automatically calculates optimal page distribution based on content volume
class PdfService {
  // Performance optimizations - load fonts once
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.MemoryImage? _logoImage;

  // Layout constants optimized for readability and professional appearance
  static const double _pageMargin = 20.0;
  static const double _headerHeight =
      100.0; // Reduced from 120.0 for more compact header
  static const double _footerHeight = 50.0;
  static const double _itemRowHeight = 12.0;
  static const double _summaryHeight = 120.0;
  static const double _tableHeaderHeight = 25.0;
  static const double _sectionSpacing = 8.0;
  static const double _grossTotalHeight =
      30.0; // Height for gross total in words section

  // Multi-page trigger thresholds - ADJUST THESE TO CONTROL PAGINATION
  static const int FORCE_MULTIPAGE_ITEM_COUNT =
      15; // Force multi-page when more than this many items
  static const int ITEMS_PER_TABLE_PAGE =
      25; // Items per page for optimal layout

  /// Main PDF generation supporting N number of pages
  Future<void> generateShipmentPDF(
      Shipment shipment, List<dynamic> items) async {
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
      final paginationPlan = _calculateOptimalPagination(items);
      final totalPages = paginationPlan['totalPages'] as int;
      final pageLayouts =
          paginationPlan['layouts'] as List<Map<String, dynamic>>;

      print(
          '📄 Intelligent pagination: $totalPages pages using ${paginationPlan['strategy']} strategy');

      // Generate each page dynamically
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final layout = pageLayouts[pageIndex];
        print('📄 Building page ${pageIndex + 1}/${totalPages}: ${layout['type']}');

        pdf.addPage(_buildDynamicPage(
            shipment, items, layout, pageIndex + 1, totalPages, _logoImage!));

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

  /// Intelligent pagination calculator - purely content-driven
  Map<String, dynamic> _calculateOptimalPagination(List<dynamic> items) {
    print('🔍 Analyzing content for dynamic pagination...');
    print('📊 Dataset size: ${items.length} items');

    // Calculate available space per page
    final double availablePerPage = PdfPageFormat.a4.height -
        (_pageMargin * 2) -
        _headerHeight -
        _footerHeight;

    // Calculate unique product types for table 2
    final Set<String> productTypes = {};
    for (final item in items) {
      productTypes.add(_getItemValue(item, 'type', 'UNKNOWN').toUpperCase());
    }

    // Calculate exact content requirements
    final double summaryHeight = _summaryHeight;
    final double table1HeaderHeight = _tableHeaderHeight;
    final double table1DataHeight = items.length * _itemRowHeight;
    final double table2HeaderHeight = _tableHeaderHeight;
    final double table2DataHeight =
        (productTypes.length + 1) * _itemRowHeight; // +1 for total row
    final double grossTotalHeight = _grossTotalHeight;
    final double spacingBetweenSections = _sectionSpacing *
        3; // Between summary-table1, table1-table2, table2-gross

    final double totalContentNeeded = summaryHeight +
        table1HeaderHeight +
        table1DataHeight +
        table2HeaderHeight +
        table2DataHeight +
        grossTotalHeight +
        spacingBetweenSections;

    print('📏 Content analysis:');
    print('   Summary: ${summaryHeight}px');
    print('   Table 1 header: ${table1HeaderHeight}px');
    print('   Table 1 data: ${table1DataHeight}px (${items.length} items)');
    print('   Table 2 header: ${table2HeaderHeight}px');
    print(
        '   Table 2 data: ${table2DataHeight}px (${productTypes.length} types + total)');
    print('   Gross total: ${grossTotalHeight}px');
    print('   Spacing: ${spacingBetweenSections}px');
    print('   Total content needed: ${totalContentNeeded}px');
    print('   Available per page: ${availablePerPage}px');
    print(
        '   Content fits in one page: ${totalContentNeeded <= availablePerPage}');

    List<Map<String, dynamic>> layouts = [];
    String strategy = '';

    if (totalContentNeeded <= availablePerPage) {
      // Everything fits on one page - show all content together
      print('✅ All content fits on single page - using single page layout');
      strategy = 'single_page_all_content';
      layouts.add({
        'type': 'summary_and_table1_and_table2',
        'pageNumber': 1,
        'showSummary': true,
        'showTable1': true,
        'showTable2': true,
        'table1Start': 0,
        'table1End': items.length,
      });
    } else {
      // Content exceeds one page - split intelligently
      print('📄 Content exceeds one page - implementing multi-page strategy');

      int currentPage = 1;
      int table1StartIndex = 0;
      double remainingPageSpace = availablePerPage;

      // Page 1: Summary + as many items as possible
      remainingPageSpace -=
          (summaryHeight + _sectionSpacing + table1HeaderHeight);

      if (remainingPageSpace > 0) {
        int itemsFitOnFirstPage = (remainingPageSpace / _itemRowHeight).floor();
        itemsFitOnFirstPage = itemsFitOnFirstPage.clamp(
            1, items.length); // At least 1 item, max all items

        print(
            '📄 Page 1: Summary + ${itemsFitOnFirstPage} items (1-${itemsFitOnFirstPage})');

        layouts.add({
          'type': 'summary_and_table1_partial',
          'pageNumber': currentPage,
          'showSummary': true,
          'showTable1': true,
          'showTable2': false,
          'table1Start': 0,
          'table1End': itemsFitOnFirstPage,
        });

        table1StartIndex = itemsFitOnFirstPage;
        currentPage++;
      }

      // Continue with remaining items on subsequent pages
      while (table1StartIndex < items.length) {
        double pageSpace = availablePerPage - table1HeaderHeight;

        // Calculate remaining items
        int remainingItems = items.length - table1StartIndex;

        // Check if this could be the last page (include space for Table 2)
        double spaceForTable2 = table2HeaderHeight +
            table2DataHeight +
            _sectionSpacing +
            grossTotalHeight +
            _sectionSpacing;
        double spaceForItemsOnLastPage = pageSpace - spaceForTable2;

        // Calculate max items that can fit on last page with Table 2
        int maxItemsOnLastPage = spaceForItemsOnLastPage > 0
            ? (spaceForItemsOnLastPage / _itemRowHeight).floor()
            : 0;

        print('📊 Page ${currentPage} analysis:');
        print('   Remaining items: $remainingItems');
        print('   Page space: ${pageSpace}px');
        print('   Space for Table 2: ${spaceForTable2}px');
        print('   Space for items on last page: ${spaceForItemsOnLastPage}px');
        print('   Max items on last page: $maxItemsOnLastPage');

        // If this is definitely the last page (remaining items can fit with Table 2)
        if (remainingItems <= maxItemsOnLastPage && maxItemsOnLastPage > 0) {
          // This is the last page - include remaining items + Table 2 + Gross Total
          print(
              '✅ Final page: ${remainingItems} items (${table1StartIndex + 1}-${items.length}) + PRODUCT SUMMARY');

          layouts.add({
            'type': 'table1_final_and_table2',
            'pageNumber': currentPage,
            'showSummary': false,
            'showTable1': true,
            'showTable2': true,
            'table1Start': table1StartIndex,
            'table1End': items.length,
          });

          break; // Exit loop - all items distributed
        } else {
          // This is NOT the last page - fill with as many items as possible
          int itemsOnThisPage;

          // If remaining items after this page would be too few for the last page,
          // adjust to leave more for the final page
          int itemsAfterThisPage = remainingItems - (pageSpace / _itemRowHeight).floor();
          if (itemsAfterThisPage > 0 &&
              itemsAfterThisPage <= 2 &&
              maxItemsOnLastPage >= itemsAfterThisPage) {
            // Reduce items on this page to leave more for the last page with Table 2
            itemsOnThisPage = Math.max(1, remainingItems - maxItemsOnLastPage);
            print(
                '📄 Adjusted page ${currentPage}: ${itemsOnThisPage} items to optimize last page');
          } else {
            // Fill this page completely
            itemsOnThisPage = (pageSpace / _itemRowHeight).floor().clamp(1, remainingItems);
          }

          print(
              '📄 Continuation page ${currentPage}: ${itemsOnThisPage} items (${table1StartIndex + 1}-${table1StartIndex + itemsOnThisPage})');

          layouts.add({
            'type': 'table1_continuation',
            'pageNumber': currentPage,
            'showSummary': false,
            'showTable1': true,
            'showTable2': false,
            'table1Start': table1StartIndex,
            'table1End': table1StartIndex + itemsOnThisPage,
          });

          table1StartIndex += itemsOnThisPage;
          currentPage++;

          // Safety check: If we've processed all items but haven't added Table 2 yet,
          // ensure we don't exit the loop without adding the final page
          if (table1StartIndex >= items.length && !layouts.any((layout) => layout['showTable2'] == true)) {
            print('🚨 Safety: All items processed but Table 2 not added - adding final page');
            layouts.add({
              'type': 'table2_only',
              'pageNumber': currentPage,
              'showSummary': false,
              'showTable1': false,
              'showTable2': true,
              'table1Start': 0,
              'table1End': 0,
            });
            break;
          }
        }
      }

      // Safety check: Ensure Table 2 is always added if not already included
      bool hasTable2 = layouts.any((layout) => layout['showTable2'] == true);
      if (!hasTable2) {
        print('🚨 Safety check: Adding Table 2 to dedicated final page');
        layouts.add({
          'type': 'table2_only',
          'pageNumber': currentPage,
          'showSummary': false,
          'showTable1': false,
          'showTable2': true,
          'table1Start': 0,
          'table1End': 0,
        });
      }

      print('📊 Final pagination: ${layouts.length} pages, all ${items.length} items distributed');
      print('   Page breakdown:');
      for (int i = 0; i < layouts.length; i++) {
        final layout = layouts[i];
        final start = layout['table1Start'] ?? 0;
        final end = layout['table1End'] ?? 0;
        final itemCount = end - start;
        print('   Page ${i + 1}: ${layout['type']} (${itemCount} items, ${start + 1}-${end})');
      }
      strategy = 'content_driven_multi_page';
    }

    print('📋 Selected strategy: $strategy with ${layouts.length} pages');

    return {
      'totalPages': layouts.length,
      'layouts': layouts,
      'strategy': strategy,
      'itemsPerPage': layouts.length == 1 ? items.length : 'variable',
    };
  }

  /// Build a dynamic page based on layout configuration
  pw.Page _buildDynamicPage(
      Shipment shipment,
      List<dynamic> items,
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

            // Add "continued from" indicator for continuation pages
            if (pageNumber > 1 && layout['showTable1'] == true) ...[
              pw.Container(
                padding: pw.EdgeInsets.all(4),
                margin: pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.orange200, width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '← Continued from previous page ←',
                      style: pw.TextStyle(
                        font: _boldFont!,
                        fontSize: 8,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Dynamic content based on layout
            ...(_buildPageContent(
                shipment, items, layout, pageNumber, totalPages)),

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
    String pageTitle = _getPageTitle(pageType);
    bool isContinuation = pageNumber > 1;

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
                'INVOICE',
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

  /// Get appropriate page title based on page type
  String _getPageTitle(String pageType) {
    switch (pageType) {
      case 'complete_invoice':
        return 'Complete Invoice Document';
      case 'summary_and_table2':
        return 'Invoice Summary & Product Types';
      case 'summary_and_table1_and_table2':
        return 'Invoice Summary & Manifest';
      case 'summary_only':
        return 'Invoice Summary';
      case 'summary_and_table1_partial':
        return 'Invoice Summary & Manifest (Part 1)';
      case 'table1_continuation':
        return 'Itemized Manifest (Continued)';
      case 'table1_final_and_table2':
        return 'Itemized Manifest (Final) & Product Summary';
      case 'table1_start':
        return 'Detailed Itemized Manifest';
      case 'table2_only':
        return 'Product Type Summary';
      default:
        return 'Invoice Document';
    }
  }

  /// Build dynamic page content based on layout
  List<pw.Widget> _buildPageContent(Shipment shipment, List<dynamic> items,
      Map<String, dynamic> layout, int pageNumber, int totalPages) {
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

    // Add Gross Total in words if Table 2 is shown (final page or single page)
    if (layout['showTable2'] == true) {
      print('📄 Adding Gross Total to page $pageNumber');
      final totalAmount = _calculateProductSummary(items)['total'] as double;
      content.add(pw.SizedBox(height: _sectionSpacing));
      content.add(_buildGrossTotalInWords(totalAmount));
    }

    // Add continuation indicator for non-final pages (only if not showing Table 2)
    if (pageNumber < totalPages &&
        layout['showTable1'] == true &&
        layout['showTable2'] == false) {
      final int endIdx = layout['table1End'] ?? items.length;
      if (endIdx < items.length) {
        content.add(pw.SizedBox(height: 8));
        content.add(
          pw.Container(
            padding: pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '→ Data continues on next page →',
                  style: pw.TextStyle(
                    font: _boldFont!,
                    fontSize: 8,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ),
        );
      }
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
    final itemsToShow = items.sublist(startIndex, endIndex);

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
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ITEMIZED MANIFEST',
                    style: pw.TextStyle(
                        font: _boldFont!,
                        fontSize: 10,
                        color: PdfColors.white)), // Reduced from 12
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (totalPages > 1)
                      pw.Container(
                        padding:
                            pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white.shade(0.2),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                            'Items ${startIndex + 1}-$endIndex of ${items.length}',
                            style: pw.TextStyle(
                                font: _boldFont!,
                                fontSize: 8,
                                color: PdfColors.white)),
                      ),
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
            // Add continuation indicators
            if (totalPages > 1) ...[
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (startIndex > 0)
                    pw.Text('← Continued from previous page',
                        style: pw.TextStyle(
                            font: _regularFont!,
                            fontSize: 6,
                            color: PdfColors.white)),
                  if (endIndex < items.length)
                    pw.Text('Continued on next page →',
                        style: pw.TextStyle(
                            font: _regularFont!,
                            fontSize: 6,
                            color: PdfColors.white)),
                ],
              ),
            ],
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

    for (int index = 0; index < items.length; index++) {
      final item = items[index];
      final weight = double.tryParse(_getItemValue(item, 'weight', '0')) ?? 0.0;
      String currentBoxNumber =
          _getItemValue(item, 'boxNumber', 'Box ${baseIndex + index + 1}');

      // Smart box number display
      String displayBoxNumber = '';
      if (currentBoxNumber != previousBoxNumber) {
        displayBoxNumber = currentBoxNumber;
        previousBoxNumber = currentBoxNumber;
      }

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
      case 'complete_invoice':
        return 'Complete Invoice ($totalItems items)';
      case 'summary_and_table2':
        return 'Invoice Summary & Types';
      case 'summary_and_table1_and_table2':
        return 'Invoice Summary & Manifest';
      case 'summary_only':
        return 'Invoice Summary';
      case 'summary_and_table1_partial':
        return 'Invoice Summary & Manifest (Continued on next page...)';
      case 'table1_continuation':
        return 'Manifest Continued (Items from previous page)';
      case 'table1_final_and_table2':
        return 'Manifest Final Page & Product Types';
      case 'table1_start':
        return 'Detailed Manifest (Continued...)';
      case 'table2_only':
        return 'Product Type Summary';
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
