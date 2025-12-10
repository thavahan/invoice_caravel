import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  static const double _headerHeight = 100.0;
  static const double _footerHeight = 50.0;
  static const double _itemRowHeight = 15.0;
  static const double _summaryHeight = 120.0;
  static const double _tableHeaderHeight = 25.0;
  static const double _sectionSpacing = 8.0;

  // Multi-page trigger thresholds - ADJUST THESE TO CONTROL PAGINATION
  static const int FORCE_MULTIPAGE_ITEM_COUNT =
      1; // LOWERED FOR TESTING - Force multi-page when more than this many items
  static const int ITEMS_PER_TABLE_PAGE =
      8; // Increased for better production use - items per page

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
        print('📄 Building page ${pageIndex + 1}: ${layout['type']}');

        pdf.addPage(_buildDynamicPage(
            shipment, items, layout, pageIndex + 1, totalPages, _logoImage!));
      }

      print('📄 Successfully generated $totalPages pages');
      await _outputPDF(pdf, shipment);
    } catch (e, stackTrace) {
      print('❌ PDF Generation Error: $e');
      print('📄 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Intelligent pagination calculator - supports unlimited pages
  Map<String, dynamic> _calculateOptimalPagination(List<dynamic> items) {
    print('🔍 Analyzing content for optimal N-page distribution...');
    print('📊 Dataset size: ${items.length} items');

    // Calculate content requirements
    final double table1Height =
        _tableHeaderHeight + (items.length * _itemRowHeight);

    // Calculate unique flower types for table 2
    final Set<String> flowerTypes = {};
    for (final item in items) {
      flowerTypes.add(_getItemValue(item, 'type', 'UNKNOWN').toUpperCase());
    }
    final double table2Height =
        _tableHeaderHeight + ((flowerTypes.length + 1) * _itemRowHeight);

    // Calculate available space per page (dynamic calculation)
    final double availablePerPage = PdfPageFormat.a4.height -
        (_pageMargin * 2) -
        _headerHeight -
        _footerHeight;

    print('📏 Content analysis:');
    print('   Summary required: ${_summaryHeight}px');
    print('   Table 1 required: ${table1Height}px (${items.length} items)');
    print(
        '   Table 2 required: ${table2Height}px (${flowerTypes.length} flower types)');
    print('   Available per page: ${availablePerPage}px');
    print(
        '   Estimated items per page: ${(availablePerPage / _itemRowHeight).floor()}');

    List<Map<String, dynamic>> layouts = [];
    String strategy = '';

    // Strategy selection based on content volume
    final double totalContentNeeded = _summaryHeight +
        table1Height +
        table2Height +
        10; // +10 for reduced spacing

    print('📏 Decision point:');
    print('   Total content needed: ${totalContentNeeded}px');
    print('   Available per page: ${availablePerPage}px');
    print('   Content exceeds page: ${totalContentNeeded > availablePerPage}');

    // Intelligent pagination: split content across pages if needed
    if (totalContentNeeded <= availablePerPage) {
      // Everything fits on one page
      strategy = 'summary_table1_table2_single_page';
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
      // Content exceeds one page - implement intelligent splitting
      print('📄 Large dataset detected - implementing multi-page strategy');
      print(
          '📈 Estimated pages needed: ${((items.length * _itemRowHeight) / availablePerPage).ceil() + 1}');

      double remainingSpace = availablePerPage;
      int currentPage = 1;
      int table1StartIndex = 0;
      int totalItemsProcessed = 0;

      // Page 1: Always include summary + as much of table 1 as possible
      remainingSpace -= _summaryHeight + _sectionSpacing;
      if (remainingSpace > 0) {
        // Calculate available space for table 1 on page 1 (include header space)
        double availableForTable1 = remainingSpace - _tableHeaderHeight;
        int itemsPerPage = (availableForTable1 / _itemRowHeight).floor();
        itemsPerPage = itemsPerPage > 0 ? itemsPerPage : 1; // At least 1 item
        int table1EndIndex =
            (table1StartIndex + itemsPerPage).clamp(0, items.length);
        totalItemsProcessed += (table1EndIndex - table1StartIndex);

        print(
            '📄 Page 1: Summary + ${table1EndIndex - table1StartIndex} items (${table1StartIndex + 1}-${table1EndIndex})');

        layouts.add({
          'type': 'summary_and_table1_partial',
          'pageNumber': currentPage,
          'showSummary': true,
          'showTable1': true,
          'showTable2': false,
          'table1Start': table1StartIndex,
          'table1End': table1EndIndex,
        });

        table1StartIndex = table1EndIndex;
        currentPage++;
      }

      // Subsequent pages: Continue with remaining table 1 items
      while (table1StartIndex < items.length) {
        // Calculate maximum items that can fit on subsequent pages
        double spaceForItems = availablePerPage - _tableHeaderHeight;

        // Check if this would be the last batch of items
        int potentialItemsPerPage = (spaceForItems / _itemRowHeight).floor();
        bool isLastPage =
            (table1StartIndex + potentialItemsPerPage) >= items.length;

        if (isLastPage) {
          // Last page needs space for flower type summary - calculate more precisely
          double spaceNeededForTable2 =
              _tableHeaderHeight + ((flowerTypes.length + 1) * _itemRowHeight);
          spaceForItems -= (spaceNeededForTable2 + _sectionSpacing);
        }

        int itemsPerPage = (spaceForItems / _itemRowHeight).floor();
        itemsPerPage = itemsPerPage > 0 ? itemsPerPage : 1;
        int table1EndIndex =
            (table1StartIndex + itemsPerPage).clamp(0, items.length);

        // Recalculate if we're actually on the last page after adjustment
        bool actuallyLastPage = table1EndIndex >= items.length;
        totalItemsProcessed += (table1EndIndex - table1StartIndex);

        print(
            '📄 Page ${currentPage}: ${table1EndIndex - table1StartIndex} items (${table1StartIndex + 1}-${table1EndIndex})${actuallyLastPage ? ' + Summary' : ''}');

        layouts.add({
          'type': actuallyLastPage
              ? 'table1_final_and_table2'
              : 'table1_continuation',
          'pageNumber': currentPage,
          'showSummary': false,
          'showTable1': true,
          'showTable2': actuallyLastPage, // Show table 2 only on final page
          'table1Start': table1StartIndex,
          'table1End': table1EndIndex,
        });

        table1StartIndex = table1EndIndex;
        currentPage++;
      }

      print(
          '📊 Final pagination: ${layouts.length} pages, ${totalItemsProcessed} items processed');
      strategy = 'intelligent_multi_page_pagination_large_dataset';
    }

    print('📋 Selected strategy: $strategy with ${layouts.length} pages');

    // Performance optimization for large datasets
    if (items.length > 20) {
      print(
          '🚀 Large dataset optimization: Processing ${items.length} items across ${layouts.length} pages');
      print(
          '📊 Average items per page: ${(items.length / layouts.length).toStringAsFixed(1)}');
    }

    return {
      'totalPages': layouts.length,
      'layouts': layouts,
      'strategy': strategy,
      'itemsPerPage': strategy.contains('table1') && layouts.length > 1
          ? (layouts.where((l) => l['showTable1'] == true).first['table1End']
                  as int) -
              (layouts
                  .where((l) => l['showTable1'] == true)
                  .first['table1Start'] as int)
          : items.length,
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
            pw.SizedBox(height: 20),

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

    return pw.Container(
      width: double.infinity,
      height: _headerHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(width: 0.4, color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        children: [
          // Logo section
          pw.Container(
            width: 80,
            padding: pw.EdgeInsets.all(10),
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
            padding: pw.EdgeInsets.all(15),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice: ${shipment.invoiceNumber}',
                          style: pw.TextStyle(font: _boldFont!, fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('AWB:',
                              style: pw.TextStyle(
                                  font: _regularFont!, fontSize: 9)),
                          pw.SizedBox(width: 8),
                          pw.Container(
                            width: 80,
                            height: 16,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  width: 1, color: PdfColors.black),
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Center(
                              child: pw.Text('',
                                  style: pw.TextStyle(
                                      font: _regularFont!, fontSize: 8)),
                            ),
                          ),
                        ],
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
        return 'Invoice Summary & Flower Types';
      case 'summary_and_table1_and_table2':
        return 'Invoice Summary & Manifest';
      case 'summary_only':
        return 'Invoice Summary';
      case 'summary_and_table1_partial':
        return 'Invoice Summary & Manifest (Part 1)';
      case 'table1_continuation':
        return 'Itemized Manifest (Continued)';
      case 'table1_final_and_table2':
        return 'Itemized Manifest (Final) & Summary';
      case 'table1_start':
        return 'Detailed Itemized Manifest';
      case 'table2_only':
        return 'Flower Type Summary';
      default:
        return 'Invoice Document';
    }
  }

  /// Build dynamic page content based on layout
  List<pw.Widget> _buildPageContent(Shipment shipment, List<dynamic> items,
      Map<String, dynamic> layout, int pageNumber, int totalPages) {
    List<pw.Widget> content = [];

    // Add invoice summary if required
    if (layout['showSummary'] == true) {
      content.addAll(_buildInvoiceSummary(shipment, items));
    }

    // Add spacing between sections
    if (content.isNotEmpty) {
      content.add(pw.SizedBox(height: 2)); // Minimal spacing
    }

    // Add Table 1 if required
    if (layout['showTable1'] == true) {
      final int startIdx = layout['table1Start'] ?? 0;
      final int endIdx = layout['table1End'] ?? items.length;
      content.addAll(
          _buildTable1(items, startIdx, endIdx, pageNumber, totalPages));
    }

    // Add spacing between tables
    if (layout['showTable1'] == true && layout['showTable2'] == true) {
      content.add(pw.SizedBox(height: 2)); // Minimal spacing
    }

    // Add Table 2 if required
    if (layout['showTable2'] == true) {
      content.addAll(_buildTable2(items));
    }

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

      // Shipment Information and Consignee Row
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _buildShipmentInfo(shipment, items),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding: pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5, color: PdfColors.orange600),
                borderRadius: pw.BorderRadius.circular(5),
                color: PdfColors.orange50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CONSIGNEE DETAILS',
                      style: pw.TextStyle(
                          font: _boldFont!,
                          fontSize: 9, // Reduced from 10
                          color: PdfColors.orange800)),
                  pw.SizedBox(height: 5),
                  _buildDetailRow('Company', shipment.consignee),
                  _buildDetailRow(
                      'Address',
                      shipment.consigneeAddress.isEmpty
                          ? 'Not provided'
                          : shipment.consigneeAddress),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Build shipment information section (appears on every page)
  pw.Widget _buildShipmentInfo(Shipment shipment, List<dynamic> items) {
    return pw.Container(
      padding: pw.EdgeInsets.all(5), // Reduced from 8
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.purple600),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.purple50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('SHIPMENT INFORMATION',
                  style: pw.TextStyle(
                      font: _boldFont!,
                      fontSize: 10,
                      color: PdfColors.purple800)),
              pw.Spacer(),
              pw.Text(
                  'Date of Issue: ${shipment.dateOfIssue != null ? _formatDate(shipment.dateOfIssue!) : 'N/A'}',
                  style: pw.TextStyle(
                      font: _boldFont!,
                      fontSize: 8,
                      color: PdfColors.purple800)),
            ],
          ),
          pw.SizedBox(height: 2), // Reduced from 5
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Invoice No', shipment.invoiceNumber),
                    _buildDetailRow(
                        'Invoice Date',
                        shipment.invoiceDate != null
                            ? _formatDate(shipment.invoiceDate!)
                            : 'N/A'),
                    _buildDetailRow('Flight No', shipment.flightNo),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Origin',
                        shipment.origin.isEmpty ? 'N/A' : shipment.origin),
                    _buildDetailRow('Destination', shipment.dischargeAirport),
                    _buildDetailRow('ETA', _formatDate(shipment.eta)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper to build detail rows
  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80, // Fixed width for label area
            child: pw.Text(label,
                style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
          ),
          pw.Text(': ', style: pw.TextStyle(font: _boldFont!, fontSize: 8)),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(font: _regularFont!, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  /// Build Table 1 - Itemized Manifest with pagination support
  List<pw.Widget> _buildTable1(List<dynamic> items, int startIndex,
      int endIndex, int currentPage, int totalPages) {
    final itemsToShow = items.sublist(startIndex, endIndex);

    return [
      // Table header with pagination info
      pw.Container(
        padding: pw.EdgeInsets.all(5), // Reduced from 8
        decoration: pw.BoxDecoration(
          color: PdfColors.grey800,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(5),
            topRight: pw.Radius.circular(5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ITEMIZED MANIFEST',
                style: pw.TextStyle(
                    font: _boldFont!,
                    fontSize: 10,
                    color: PdfColors.white)), // Reduced from 12
            if (totalPages > 1)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1), // Reduced padding
                decoration: pw.BoxDecoration(
                  color: PdfColors.white.shade(0.2),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                    'Items ${startIndex + 1}-$endIndex of ${items.length}',
                    style: pw.TextStyle(
                        font: _boldFont!, fontSize: 8, color: PdfColors.white)),
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

  /// Build Table 2 - Flower Type Summary
  List<pw.Widget> _buildTable2(List<dynamic> items) {
    // Calculate flower type summary
    Map<String, Map<String, double>> flowerSummary = {};

    for (final item in items) {
      String flowerType = _getItemValue(item, 'type', 'UNKNOWN').toUpperCase();
      double weight =
          double.tryParse(_getItemValue(item, 'weight', '0')) ?? 0.0;
      double rate = double.tryParse(_getItemValue(item, 'rate', '0')) ?? 0.0;

      if (flowerSummary.containsKey(flowerType)) {
        flowerSummary[flowerType]!['totalWeight'] =
            (flowerSummary[flowerType]!['totalWeight'] ?? 0.0) + weight;
        flowerSummary[flowerType]!['totalAmount'] =
            (flowerSummary[flowerType]!['totalAmount'] ?? 0.0) +
                (weight * rate);
      } else {
        flowerSummary[flowerType] = {
          'rate': rate,
          'totalWeight': weight,
          'totalAmount': weight * rate,
        };
      }
    }

    var sortedTypes = flowerSummary.keys.toList()..sort();
    double grandTotalWeight = 0.0;
    double grandTotalAmount = 0.0;

    List<pw.TableRow> rows = [];

    // Build data rows
    for (int index = 0; index < sortedTypes.length; index++) {
      String flowerType = sortedTypes[index];
      var summary = flowerSummary[flowerType]!;

      double totalWeight = summary['totalWeight'] ?? 0.0;
      double rate = summary['rate'] ?? 0.0;
      double totalAmount = summary['totalAmount'] ?? 0.0;

      grandTotalWeight += totalWeight;
      grandTotalAmount += totalAmount;

      rows.add(
        pw.TableRow(
            decoration: index % 2 == 0
                ? pw.BoxDecoration(color: PdfColors.grey50)
                : null,
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(3),
                child: pw.Text(flowerType,
                    style: pw.TextStyle(font: _regularFont!, fontSize: 7)),
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
          color: PdfColors.grey800,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(5),
            topRight: pw.Radius.circular(5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SUMMARY BY Flower TYPE',
                style: pw.TextStyle(
                    font: _boldFont!,
                    fontSize: 10,
                    color: PdfColors.white)), // Reduced from 12
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                  horizontal: 4, vertical: 1), // Reduced padding
              decoration: pw.BoxDecoration(
                color: PdfColors.white.shade(0.2),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text('${sortedTypes.length} Types',
                  style: pw.TextStyle(
                      font: _boldFont!, fontSize: 8, color: PdfColors.white)),
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
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(3),
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: [
            pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableHeader('TYPE'),
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
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(3),
          },
          border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
          children: rows,
        ),
      ),
    ];
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
        return 'Invoice Summary & Manifest';
      case 'table1_continuation':
        return 'Manifest Continued';
      case 'table1_final_and_table2':
        return 'Manifest & Flower Types';
      case 'table1_start':
        return 'Detailed Manifest';
      case 'table2_only':
        return 'Flower Type Summary';
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

    String stemsText = hasStems ? 'WITH STEMS' : 'NO STEMS';
    String description = '$flowerType, $stemsText, APPROX $approxQuantity NOS';

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
