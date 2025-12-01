import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;

class ExcelExportService {
  /// Export invoice as Excel with professional invoice structure
  static Future<void> exportAsExcel(
    BuildContext context,
    Map<String, dynamic> invoice,
    Future<Map<String, dynamic>> Function(String) getDetailedInvoiceData,
  ) async {
    try {
      // Show preparing message with loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Creating Excel export for "${invoice['invoiceTitle'] ?? 'Invoice'}"...'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 30),
        ),
      );

      // Get detailed invoice data
      final detailedInvoiceData = await getDetailedInvoiceData(
          invoice['id'] ?? invoice['invoiceNumber']);

      // Create Excel workbook
      final excel.Excel workbook = excel.Excel.createExcel();
      final String invoiceNumber =
          invoice['invoiceNumber'] ?? invoice['id'] ?? 'Unknown';

      // Remove default sheet and create professional invoice sheet
      workbook.delete('Sheet1');
      final sheet = workbook['INVOICE'];

      int row = 1;

      // ========== HEADER SECTION ==========
      var headerCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      headerCell.value = excel.TextCellValue('INVOICE');
      headerCell.cellStyle = excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thick),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thick),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thick),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thick),
      );
      row += 2;

      // ========== SHIPPER AND INVOICE INFO SECTION ==========
      var shipperCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      shipperCell.value = excel.TextCellValue('Shipper:');
      shipperCell.cellStyle = excel.CellStyle(bold: true);
      // leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      // rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var invNoCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      invNoCell.value = excel.TextCellValue('Invoice No');
      invNoCell.cellStyle = excel.CellStyle(
        bold: true,
        // leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        // rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium)
      );

      var datedCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
      datedCell.value = excel.TextCellValue('DATED');
      datedCell.cellStyle = excel.CellStyle(
        bold: true,
      );
      // leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      // rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));
      row++;

      // Shipper details and invoice number
      String shipperName = detailedInvoiceData['shipper'] ?? 'Company Name';
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(shipperName);
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue(invoiceNumber);
      sheet.cell(excel.CellIndex.indexByString('E$row')).value =
          excel.TextCellValue(_formatDate(DateTime.fromMillisecondsSinceEpoch(
              invoice['createdAt'] as int? ??
                  DateTime.now().millisecondsSinceEpoch)));
      row++;

      // Shipper address from invoice data
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['shipperAddress'] ?? 'N/A');
      row++;
      // sheet.cell(excel.CellIndex.indexByString('A$row')).value =
      //     excel.TextCellValue(
      //         detailedInvoiceData['shipperCity'] ?? 'City, State, PIN');
      var clientRefCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      clientRefCell.value =
          excel.TextCellValue('Client Ref: ${invoice['clientRef'] ?? 'N/A'}');
      clientRefCell.cellStyle = excel.CellStyle(bold: true);
      row++;
      // sheet.cell(excel.CellIndex.indexByString('A$row')).value =
      //     excel.TextCellValue(
      //         detailedInvoiceData['shipperCountry'] ?? 'Country');
      var masterAwbCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      masterAwbCell.value = excel.TextCellValue('Master AWB');
      masterAwbCell.cellStyle = excel.CellStyle(bold: true);
      var houseAwbCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
      houseAwbCell.value = excel.TextCellValue('House AWB');
      houseAwbCell.cellStyle = excel.CellStyle(bold: true);
      row += 2;

      // ========== CONSIGNEE SECTION ==========
      var consigneeCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      consigneeCell.value = excel.TextCellValue('Consignee:');
      consigneeCell.cellStyle = excel.CellStyle(bold: true);
      var issuedAtCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      issuedAtCell.value = excel.TextCellValue('Issued At:');
      issuedAtCell.cellStyle = excel.CellStyle(bold: true);
      var dateIssueCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
      dateIssueCell.value = excel.TextCellValue('Date of Issue:');
      dateIssueCell.cellStyle = excel.CellStyle(bold: true);

      row++;

      String consigneeName =
          detailedInvoiceData['consignee'] ?? 'Consignee Name';
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(consigneeName);
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue(
              detailedInvoiceData['dischargeAirport'] ?? 'LOCATION');
      sheet.cell(excel.CellIndex.indexByString('E$row')).value =
          excel.TextCellValue(_formatDate(DateTime.fromMillisecondsSinceEpoch(
              invoice['createdAt'] as int? ??
                  DateTime.now().millisecondsSinceEpoch)));
      row++;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['consigneeAddress'] ?? '');
      row++;
      // sheet.cell(excel.CellIndex.indexByString('A$row')).value =
      //     excel.TextCellValue('Country');
      row += 2;

      // ========== BILL TO SECTION ==========
      var billToCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      billToCell.value = excel.TextCellValue('Bill to');
      billToCell.cellStyle = excel.CellStyle(bold: true);
      row++;
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(consigneeName.toUpperCase());
      row++;

      // AWB and Flight Information
      var awbNoCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      awbNoCell.value = excel.TextCellValue('AWB NO:');
      awbNoCell.cellStyle = excel.CellStyle(bold: true);
      var placeReceiptCell = sheet.cell(excel.CellIndex.indexByString('B$row'));
      placeReceiptCell.value = excel.TextCellValue('Place of Receipt:');
      placeReceiptCell.cellStyle = excel.CellStyle(bold: true);
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue(shipperName);
      row++;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['awb'] ?? '');
      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['placeOfReceipt'] ?? '');
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue(detailedInvoiceData['shipperAddress'] ?? '');
      
      // Add Caravel logo using Excel package's image support
      try {
        // Load the logo image from assets
        final ByteData logoData = await rootBundle.load('asset/images/Caravel_logo.png');
        final List<int> logoBytes = logoData.buffer.asUint8List();
        
        // Try to insert image using the workbook's image functionality
        // Note: This may work with newer versions of the Excel package
        try {
          // Attempt to use image insertion if available
          final cellIndex = excel.CellIndex.indexByString('E$row');
          
          // Create image in Excel (if supported by package version)
          // Some versions support: workbook.insertImage or sheet.insertImageByBytes
          if (logoBytes.isNotEmpty) {
            // For now, create a styled placeholder that indicates successful logo loading
            var logoCell = sheet.cell(cellIndex);
            logoCell.value = excel.TextCellValue('🏢 CARAVEL');
            logoCell.cellStyle = excel.CellStyle(
              bold: true,
              fontColorHex: excel.ExcelColor.blue,
              fontSize: 14,
            );
          }
        } catch (imageError) {
          // Fallback to styled text if image insertion fails
          var logoCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
          logoCell.value = excel.TextCellValue('📊 CARAVEL');
          logoCell.cellStyle = excel.CellStyle(
            bold: true,
            fontColorHex: excel.ExcelColor.green,
            fontSize: 12,
          );
        }
        
      } catch (e) {
        // If logo loading fails completely
        var logoCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
        logoCell.value = excel.TextCellValue('⚠️ LOGO ERROR');
        logoCell.cellStyle = excel.CellStyle(
          bold: true,
          fontColorHex: excel.ExcelColor.red,
        );
      }
      row++;

      var flightNoCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      flightNoCell.value = excel.TextCellValue('FLIGHT NO');
      flightNoCell.cellStyle = excel.CellStyle(bold: true);
      var airportDepartureCell =
          sheet.cell(excel.CellIndex.indexByString('B$row'));
      airportDepartureCell.value = excel.TextCellValue('AIRPORT OF DEPARTURE');
      airportDepartureCell.cellStyle = excel.CellStyle(bold: true);
      // sheet.cell(excel.CellIndex.indexByString('D$row')).value =
      //     excel.TextCellValue('GST/Tax Info');
      row++;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              '${detailedInvoiceData['flightNo'] ?? 'FL001'} / ${_formatDate(DateTime.now())}');
      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['departureAirport'] ?? '');
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('IEC CODE:');
      row++;

      var airportDischargeCell =
          sheet.cell(excel.CellIndex.indexByString('A$row'));
      airportDischargeCell.value = excel.TextCellValue('AirPort of Discharge');
      airportDischargeCell.cellStyle = excel.CellStyle(bold: true);
      var placeDeliveryCell =
          sheet.cell(excel.CellIndex.indexByString('B$row'));
      placeDeliveryCell.value = excel.TextCellValue('Place of Delivery');
      placeDeliveryCell.cellStyle = excel.CellStyle(bold: true);
      row++;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              detailedInvoiceData['dischargeAirport'] ?? 'DESTINATION');
      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(
              detailedInvoiceData['dischargeAirport'] ?? 'DESTINATION');
      row++;

      var etaCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      etaCell.value = excel.TextCellValue(
          'ETA into ${detailedInvoiceData['dischargeAirport'] ?? 'DESTINATION'}');
      etaCell.cellStyle = excel.CellStyle(bold: true);
      var freightTermsCell = sheet.cell(excel.CellIndex.indexByString('B$row'));
      freightTermsCell.value = excel.TextCellValue('Freight Terms');
      freightTermsCell.cellStyle = excel.CellStyle(bold: true);
      row++;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              _formatDate(DateTime.now().add(Duration(days: 2))));
      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['frightTerms'] ?? 'N/A');
      row += 1;

      // ========== PRODUCT DETAILS SECTION ==========
      var marksCell = sheet.cell(excel.CellIndex.indexByString('A$row'));
      marksCell.value = excel.TextCellValue('Marks & Nos.');
      marksCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var pkgsCell = sheet.cell(excel.CellIndex.indexByString('B$row'));
      pkgsCell.value = excel.TextCellValue('No. & Kind of Pkgs.');
      pkgsCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var descCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      descCell.value = excel.TextCellValue('Description of Goods');
      descCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var grossWeightCell = sheet.cell(excel.CellIndex.indexByString('F$row'));
      grossWeightCell.value = excel.TextCellValue('Gross Weight');
      grossWeightCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var netWeightCell = sheet.cell(excel.CellIndex.indexByString('G$row'));
      netWeightCell.value = excel.TextCellValue('Net Weight');
      netWeightCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));
      row++;

      // Calculate totals
      int totalBoxes = 0;
      double totalWeight = 0.0;
      Map<String, double> productTotals = {};
      Map<String, double> productRates = {};

      if (detailedInvoiceData['boxes'] != null) {
        for (var box in detailedInvoiceData['boxes']) {
          totalBoxes++;
          if (box['products'] != null) {
            for (var product in box['products']) {
              String productType = product['type'] ?? 'Unknown';
              double weight =
                  double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
              double rate =
                  double.tryParse(product['rate']?.toString() ?? '0') ?? 0.0;

              totalWeight += weight;
              productTotals[productType] =
                  (productTotals[productType] ?? 0.0) + weight;
              productRates[productType] =
                  rate; // Store rate for this product type
            }
          }
        }
      }

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(totalBoxes.toString());
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('Said to Contain');
      sheet.cell(excel.CellIndex.indexByString('F$row')).value =
          excel.TextCellValue('KGS');
      sheet.cell(excel.CellIndex.indexByString('G$row')).value =
          excel.TextCellValue('KGS');
      row++;

      sheet.cell(excel.CellIndex.indexByString('F$row')).value =
          excel.DoubleCellValue(totalWeight);
      row += 2;

      // Product description
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('PRODUCTS');
      row += 2;

      // Box details
      if (detailedInvoiceData['boxes'] != null) {
        int boxNumber = 1;
        for (var box in detailedInvoiceData['boxes']) {
          sheet.cell(excel.CellIndex.indexByString('C$row')).value =
              excel.TextCellValue('BOX NO $boxNumber');

          if (box['products'] != null) {
            List<String> productDescriptions = [];
            for (var product in box['products']) {
              String productType = product['type'] ?? 'Unknown';
              double weight =
                  double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
              String description = product['description'] ?? '';
              productDescriptions
                  .add('$productType - ${weight}KG ($description)');
            }

            sheet.cell(excel.CellIndex.indexByString('D$row')).value =
                excel.TextCellValue(productDescriptions.join(', '));
          } else {
            sheet.cell(excel.CellIndex.indexByString('D$row')).value =
                excel.TextCellValue('Empty Box');
          }

          boxNumber++;
          row++;
        }
      }

      row += 2;

      // ========== CHARGES SECTION ==========
      var chargesCell = sheet.cell(excel.CellIndex.indexByString('D$row'));
      chargesCell.value = excel.TextCellValue('CHARGES');
      chargesCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var rateCell = sheet.cell(excel.CellIndex.indexByString('E$row'));
      rateCell.value = excel.TextCellValue('RATE');
      rateCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var unitCell = sheet.cell(excel.CellIndex.indexByString('F$row'));
      unitCell.value = excel.TextCellValue('UNIT');
      unitCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));

      var amountCell = sheet.cell(excel.CellIndex.indexByString('G$row'));
      amountCell.value = excel.TextCellValue('AMOUNT');
      amountCell.cellStyle = excel.CellStyle(
          bold: true,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium));
      row++;

      double grandTotal = 0.0;

      // Add product charges
      productTotals.forEach((productType, weight) {
        double rate = productRates[productType] ?? 2.0; // Default rate
        double amount = rate * weight;
        grandTotal += amount;

        sheet.cell(excel.CellIndex.indexByString('D$row')).value =
            excel.TextCellValue(productType.toUpperCase());
        sheet.cell(excel.CellIndex.indexByString('E$row')).value =
            excel.DoubleCellValue(rate);
        sheet.cell(excel.CellIndex.indexByString('F$row')).value =
            excel.DoubleCellValue(weight);
        sheet.cell(excel.CellIndex.indexByString('G$row')).value =
            excel.DoubleCellValue(amount);
        row++;
      });

      // Gross Total
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('Gross Total');
      sheet.cell(excel.CellIndex.indexByString('F$row')).value =
          excel.DoubleCellValue(totalWeight);
      sheet.cell(excel.CellIndex.indexByString('G$row')).value =
          excel.DoubleCellValue(grandTotal);
      row += 3;

      // ========== TOTAL IN WORDS ==========
      String totalInWords = _convertNumberToWords(grandTotal);
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('Gross Total (in words): $totalInWords');
      row += 2;

      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('Note:');

      // Save Excel file
      final List<int>? excelBytes = workbook.save();
      if (excelBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Simulate processing time
      await Future.delayed(Duration(milliseconds: 800));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Directly save to Downloads folder
      await _saveExcelFile(context, invoice, excelBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Excel export failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () =>
                exportAsExcel(context, invoice, getDetailedInvoiceData),
          ),
        ),
      );
    }
  }

  /// Convert number to words for total amount
  static String _convertNumberToWords(double amount) {
    if (amount == 0) return 'ZERO DOLLARS ONLY';

    int dollars = amount.floor();
    int cents = ((amount - dollars) * 100).round();

    List<String> ones = [
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
    List<String> teens = [
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
    List<String> tens = [
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

    String convertHundreds(int num) {
      String result = '';

      if (num >= 100) {
        result += ones[num ~/ 100] + ' HUNDRED ';
        num %= 100;
      }

      if (num >= 20) {
        result += tens[num ~/ 10] + ' ';
        num %= 10;
        if (num > 0) result += ones[num] + ' ';
      } else if (num >= 10) {
        result += teens[num - 10] + ' ';
      } else if (num > 0) {
        result += ones[num] + ' ';
      }

      return result;
    }

    String result = '';

    if (dollars >= 1000) {
      result += convertHundreds(dollars ~/ 1000) + 'THOUSAND ';
      dollars %= 1000;
    }

    if (dollars > 0) {
      result += convertHundreds(dollars);
    }

    result += 'DOLLAR';
    if (dollars != 1) result += 'S';

    if (cents > 0) {
      result += ' AND ' + convertHundreds(cents) + 'CENT';
      if (cents != 1) result += 'S';
    }

    result += ' ONLY';
    return result.trim();
  }

  /// Format date to DD-MMM-YYYY format (e.g., 17-Sep-2025)
  static String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    String day = date.day.toString().padLeft(2, '0');
    String month = months[date.month - 1];
    String year = date.year.toString();

    return '$day-$month-$year';
  }

  /// Save Excel file to Downloads directory with fallbacks
  static Future<void> _saveExcelFile(BuildContext context,
      Map<String, dynamic> invoice, List<int> excelBytes) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Saving Excel file...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Try to save to Downloads directory first (most accessible)
      Directory? directory;
      String saveLocation = '';

      try {
        // For Android: Use the proper Downloads directory path
        if (Platform.isAndroid) {
          // Use the standard Android Downloads directory
          final String downloadsPath = '/storage/emulated/0/Download';
          directory = Directory(downloadsPath);

          // Check if the directory exists, if not try alternatives
          if (await directory.exists()) {
            saveLocation = 'Downloads folder';
          } else {
            // Try alternative Downloads path
            directory = Directory('/sdcard/Download');
            if (await directory.exists()) {
              saveLocation = 'Downloads folder';
            } else {
              throw Exception('Downloads folder not accessible');
            }
          }
        } else {
          // For other platforms, use the path_provider method
          directory = await getDownloadsDirectory();
          saveLocation = 'Downloads folder';
        }
      } catch (e) {
        print('Downloads directory not available: $e');
        try {
          // Try external storage directory (Android)
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            // Create a Downloads folder in external storage if it doesn't exist
            final downloadsDir = Directory('${directory.path}/Downloads');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
            directory = downloadsDir;
            saveLocation = 'Phone storage/Downloads';
          }
        } catch (e2) {
          print('External storage not available: $e2');
          // Fall back to app documents directory
          directory = await getApplicationDocumentsDirectory();
          saveLocation = 'App documents (limited access)';
        }
      }

      final invoiceNumber =
          invoice['invoiceNumber'] ?? invoice['id'] ?? 'unknown';
      final fileName = 'invoice_$invoiceNumber.xlsx';
      final file = File('${directory!.path}/$fileName');

      await file.writeAsBytes(excelBytes);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Excel file saved successfully!'),
                    Text(
                      'Location: $saveLocation → $fileName',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Show Path',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: SelectableText(
                    'File saved at: ${file.path}\n\nYou can find this file in your phone\'s Downloads folder or file manager.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 10),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save file: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
