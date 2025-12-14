import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// Professional Excel export service with actual .xlsx file generation
/// Generates commercial invoice format matching professional standards
class ExcelFileService {
  /// Generate and save actual Excel file with professional invoice layout
  static Future<void> generateAndExportExcel(
    BuildContext context,
    Map<String, dynamic> invoice,
    Future<Map<String, dynamic>> Function(String) getDetailedInvoiceData,
  ) async {
    try {
      // Show preparing message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Generating Excel file for "${invoice['invoiceTitle'] ?? 'Invoice'}"...'),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 30),
        ),
      );

      // Get detailed invoice data
      final detailedInvoiceData = await getDetailedInvoiceData(
          invoice['id'] ?? invoice['invoiceNumber']);

      if (detailedInvoiceData.isEmpty) {
        throw Exception('Could not retrieve invoice details');
      }

      // Create Excel workbook
      final excel.Excel workbook = excel.Excel.createExcel();
      final String invoiceNumber =
          invoice['invoiceNumber'] ?? invoice['id'] ?? 'Unknown';

      // Create invoice sheet first, then remove default sheet
      final sheet = workbook['INVOICE'];
      workbook.delete('Sheet1');

      // Ensure INVOICE is the active sheet
      workbook.setDefaultSheet('INVOICE');

      int row = 1;

      // ========== ROW 1: DOCUMENT TITLE ==========
      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('INVOICE');
      sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
          excel.CellStyle(bold: true, fontSize: 12);
      row++;

      // ========== ROW 2: SHIPPER & INVOICE DETAILS HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('Shipper:');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('INV No');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue('Client Ref');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('DATED');
      sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('E$row')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('F$row')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('G$row')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      row++;

      // ========== ROW 3: SHIPPER & INVOICE DETAILS VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['shipper'] ?? 'Company Name');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(invoiceNumber);
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue(detailedInvoiceData['clientRef'] ?? '');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue(
              DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase());
      sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('E$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('F$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('G$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      row++;

      // ========== ROWS 4-6: SHIPPER ADDRESS ==========
      int shipperStartRow = row;
      row = _addFormattedAddress(
          sheet, 'A', detailedInvoiceData['shipperAddress'] ?? 'Address', row);

      // Group shipper section with borders - add borders to all columns for shipper rows
      for (int shipperRow = shipperStartRow; shipperRow < row; shipperRow++) {
        // Add borders to columns B through G for each shipper address row
        for (String col in ['B', 'C', 'D', 'E', 'F', 'G']) {
          var cell =
              sheet.cell(excel.CellIndex.indexByString('$col$shipperRow'));
          var isLastShipperRow = (shipperRow == row - 1);

          cell.cellStyle = excel.CellStyle(
            topBorder: shipperRow == shipperStartRow
                ? excel.Border(borderStyle: excel.BorderStyle.Medium)
                : excel.Border(borderStyle: excel.BorderStyle.Thin),
            bottomBorder: isLastShipperRow
                ? excel.Border(borderStyle: excel.BorderStyle.Medium)
                : excel.Border(borderStyle: excel.BorderStyle.Thin),
            leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
            rightBorder: col == 'G'
                ? excel.Border(borderStyle: excel.BorderStyle.Medium)
                : excel.Border(borderStyle: excel.BorderStyle.Thin),
          );
        }
      }
      row++;

      // ========== ROW 7: CONSIGNEE & REFERENCES HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('Consignee:');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue('Date of Issue:');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in consignee header row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 8: CONSIGNEE & REFERENCES VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['consignee'] ?? 'Consignee');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue(
              DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase());
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in consignee values row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROWS 9-10: CONSIGNEE ADDRESS ==========
      row = _addFormattedAddress(sheet, 'A',
          detailedInvoiceData['consigneeAddress'] ?? 'Address', row);
      // Add right border to column G for consignee address rows
      _applyRightBorderToColumn(sheet, 'G', 9, row - 1);
      row += 2;

      // ========== ROW 12: BILL TO HEADER ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('Bill to');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in Bill To header row (B, C, D, E, F, G)
      for (String col in ['B', 'C', 'D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 13: BILL TO VALUE ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              (detailedInvoiceData['consignee'] ?? 'Consignee').toUpperCase());
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in Bill To value row (B, C, D, E, F, G)
      for (String col in ['B', 'C', 'D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 14: AWB & PLACE OF RECEIPT HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('AWB NO:');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('Place of Receipt:');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('D$row')).value =
          excel.TextCellValue('Shipper:');
      sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in AWB header row (C, E, F, G)
      for (String col in ['C', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 15: AWB & PLACE OF RECEIPT VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(''); // Keep AWB blank as requested
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['origin'] ?? 'LOCATION');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Shipper address in column D - track rows for grouping
      int awbShipperStartRow = row;
      int shipperEndRow = _addShipperAddressGrouped(
          sheet, 'D', detailedInvoiceData['shipperAddress'] ?? 'Address', row);

      // Group shipper section with borders - add borders to columns E, F and G for shipper address rows
      for (int shipperRow = awbShipperStartRow;
          shipperRow < shipperEndRow;
          shipperRow++) {
        // Column E: Add logo continuation or empty cell with proper borders
        var cellE = sheet.cell(excel.CellIndex.indexByString('E$shipperRow'));
        var isLastShipperRow = (shipperRow == shipperEndRow - 1);

        cellE.cellStyle = excel.CellStyle(
          topBorder: shipperRow == awbShipperStartRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          bottomBorder: isLastShipperRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        );

        // Column F: Middle section
        var cellF = sheet.cell(excel.CellIndex.indexByString('F$shipperRow'));
        cellF.cellStyle = excel.CellStyle(
          topBorder: shipperRow == awbShipperStartRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          bottomBorder: isLastShipperRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        );

        // Column G: Right edge of the grouped section
        var cellG = sheet.cell(excel.CellIndex.indexByString('G$shipperRow'));
        cellG.cellStyle = excel.CellStyle(
          topBorder: shipperRow == awbShipperStartRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          bottomBorder: isLastShipperRow
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }

      // Update row to the end of shipper address section
      row = shipperEndRow;

      // Add borders to empty cells in AWB values row (C) - D, E, F, G now handled by shipper grouping
      for (String col in ['C']) {
        var emptyCell = sheet
            .cell(excel.CellIndex.indexByString('$col$awbShipperStartRow'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 16: FLIGHT & AIRPORT DEPARTURE HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('FLIGHT NO');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('AIRPORT OF DEPARTURE');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue('GST:');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in flight header row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 17: FLIGHT & AIRPORT DEPARTURE VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              '${detailedInvoiceData['flightNo'] ?? 'FL001'} /${DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase()}');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['origin'] ?? 'LOCATION');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue(detailedInvoiceData['sgstNo'] ?? 'N/A');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in flight values row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 18: AIRPORT DISCHARGE & PLACE DELIVERY HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue('AirPort of Discharge');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('Place of Delivery');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue('IEC Code');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in airport discharge header row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 19: AIRPORT DISCHARGE & PLACE DELIVERY VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(detailedInvoiceData['destination'] ?? 'DEST');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue(detailedInvoiceData['destination'] ?? 'DEST');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('C$row')).value =
          excel.TextCellValue(detailedInvoiceData['iecCode'] ?? 'N/A');
      sheet.cell(excel.CellIndex.indexByString('C$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in airport discharge values row (D, E, F, G)
      for (String col in ['D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 20: ETA & FREIGHT TERMS HEADERS ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(
              'ETA into ${detailedInvoiceData['destination'] ?? 'DEST'}');
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('Freight Terms');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in ETA header row (C, D, E, F, G)
      for (String col in ['C', 'D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 21: ETA & FREIGHT TERMS VALUES ==========
      sheet.cell(excel.CellIndex.indexByString('A$row')).value =
          excel.TextCellValue(DateFormat('dd MMM yyyy')
              .format(DateTime.now().add(Duration(days: 2)))
              .toUpperCase());
      sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      sheet.cell(excel.CellIndex.indexByString('B$row')).value =
          excel.TextCellValue('PRE PAID');
      sheet.cell(excel.CellIndex.indexByString('B$row')).cellStyle =
          excel.CellStyle(
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in ETA values row (C, D, E, F)
      for (String col in ['C', 'D', 'E', 'F', 'G']) {
        var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
        emptyCell.cellStyle = excel.CellStyle(
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }

      // Add borders to the shipping details section
      _applyRightBorderToColumn(sheet, 'G', 12, 21);
      // Add bottom border to the last row of this section
      var lastCell = sheet.cell(excel.CellIndex.indexByString('G21'));
      var currentStyle = lastCell.cellStyle ?? excel.CellStyle();
      lastCell.cellStyle = excel.CellStyle(
        fontSize: currentStyle.fontSize,
        topBorder: currentStyle.topBorder,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: currentStyle.leftBorder,
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      row += 2;

      // ========== ROW 23: PRODUCT TABLE HEADER ==========
      final headers = [
        'MARKS & NOS.',
        'NO. & KIND OF PKGS.',
        '',
        'DESCRIPTION OF GOODS',
        '',
        'GROSS WEIGHT',
        'NET WEIGHT'
      ];

      for (int col = 0; col < headers.length; col++) {
        final colLetter = String.fromCharCode(65 + col);
        var cell = sheet.cell(excel.CellIndex.indexByString('$colLetter$row'));

        // Always set a value - use empty string for blank cells to ensure proper border rendering
        cell.value = excel.TextCellValue(headers[col]);

        // Apply consistent styling to all header cells - no bottom border for MARKS & NOS. row
        cell.cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 11,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== ROW 24: PRODUCT TABLE SUBHEADER ==========
      final subHeaders = ['', '', '', 'Said to Contain', '', 'KGS', 'KGS'];

      for (int col = 0; col < subHeaders.length; col++) {
        final colLetter = String.fromCharCode(65 + col);
        var cell = sheet.cell(excel.CellIndex.indexByString('$colLetter$row'));

        // Always set a value - use empty string for blank cells to ensure proper border rendering
        cell.value = excel.TextCellValue(subHeaders[col]);

        // Apply consistent styling to all subheader cells
        cell.cellStyle = excel.CellStyle(
          bold: true,
          fontSize: 11,
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }
      row++;

      // ========== PRODUCT DETAILS ==========
      row = _addProductDetails(sheet, detailedInvoiceData, row);
      row += 3; // Reduced spacing since we have better visual separation now

      // ========== CHARGES SECTION ==========
      _addChargesSection(sheet, detailedInvoiceData, row);
      row += 10;

      // ========== TOTAL IN WORDS ==========
      _addTotalInWords(sheet, detailedInvoiceData, row);

      // Set column widths
      sheet.setColumnWidth(0, 30); // Column A - doubled width

      // Auto-size remaining columns (using integer indices: 1-6 = B-G)
      for (int i = 1; i < 7; i++) {
        sheet.setColumnAutoFit(i);
      }

      // Save the file
      final fileName = 'Invoice_${invoiceNumber}.xlsx';
      final file = await _saveExcelFile(fileName, workbook);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Directly open native share dialog
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice: $fileName',
      );
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
        ),
      );
    }
  }

  /// Apply right border to a specific column for a range of rows
  static void _applyRightBorderToColumn(
    excel.Sheet sheet,
    String columnLetter,
    int startRow,
    int endRow,
  ) {
    for (int row = startRow; row <= endRow; row++) {
      var cell = sheet.cell(excel.CellIndex.indexByString('$columnLetter$row'));
      var currentStyle = cell.cellStyle ?? excel.CellStyle();

      cell.cellStyle = excel.CellStyle(
        fontSize: currentStyle.fontSize,
        topBorder: currentStyle.topBorder,
        bottomBorder: currentStyle.bottomBorder,
        leftBorder: currentStyle.leftBorder,
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add formatted address - splits by comma and prints on separate rows
  /// Last two parts are combined in the same cell (e.g., "State - Postal Code")
  /// Includes borders on all address cells with top border for first row
  static int _addFormattedAddress(
      excel.Sheet sheet, String columnLetter, String address, int startRow) {
    if (address.isEmpty || address == 'Address') {
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(address);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      return startRow + 1;
    }

    // Split address by comma and trim whitespace
    List<String> addressParts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    // Add each part on a separate row, except combine last two parts
    if (addressParts.length <= 1) {
      // Single part - just add it
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(addressParts[0]);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    } else if (addressParts.length == 2) {
      // Two parts - combine them with " - "
      sheet
              .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
              .value =
          excel.TextCellValue('${addressParts[0]} - ${addressParts[1]}');
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    } else {
      // More than two parts - add all but last two separately, then combine last two
      for (int i = 0; i < addressParts.length - 2; i++) {
        sheet
            .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
            .value = excel.TextCellValue(addressParts[i]);
        sheet
            .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
            .cellStyle = excel.CellStyle(
          topBorder: i == 0
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : null,
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
        startRow++;
      }
      // Combine last two parts
      String lastTwoCombined =
          '${addressParts[addressParts.length - 2]} - ${addressParts[addressParts.length - 1]}';
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(lastTwoCombined);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: addressParts.length == 3
            ? excel.Border(borderStyle: excel.BorderStyle.Medium)
            : null,
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    }

    return startRow;
  }

  /// Add product details with enhanced box grouping and visual separation
  /// Format: BOX NO in column A, product details in column D with proper borders
  static int _addProductDetails(
    excel.Sheet sheet,
    Map<String, dynamic> detailedData,
    int startRow,
  ) {
    if (detailedData['boxes'] == null) return startRow;

    int boxNum = 1;
    for (var box in detailedData['boxes']) {
      // Box header row with enhanced styling
      _addBoxHeader(sheet, startRow, boxNum);
      startRow++;

      if (box['products'] != null && (box['products'] as List).isNotEmpty) {
        // Add products for this box
        for (var product in box['products']) {
          _addProductRow(sheet, startRow, product, false);
          startRow++;
        }
      } else {
        // Empty box case
        _addEmptyBoxRow(sheet, startRow);
        startRow++;
      }

      // Add separator row between boxes (except for last box)
      if (boxNum < (detailedData['boxes'] as List).length) {
        _addBoxSeparator(sheet, startRow);
        startRow++;
      }

      boxNum++;
    }

    return startRow;
  }

  /// Add box header with enhanced styling
  static void _addBoxHeader(excel.Sheet sheet, int row, int boxNum) {
    // BOX NO in column A with enhanced styling
    sheet.cell(excel.CellIndex.indexByString('A$row')).value =
        excel.TextCellValue('BOX NO $boxNum');
    sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
        excel.CellStyle(
      bold: true,
      fontSize: 11,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Header label in column D
    sheet.cell(excel.CellIndex.indexByString('D$row')).value =
        excel.TextCellValue('PRODUCTS');
    sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
        excel.CellStyle(
      bold: true,
      fontSize: 10,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in box header row (B, C, E, F, G)
    for (String col in ['B', 'C', 'E', 'F', 'G']) {
      var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
      emptyCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add product row with proper styling
  static void _addProductRow(excel.Sheet sheet, int row,
      Map<String, dynamic> product, bool isLastInBox) {
    // Empty cell in column A for product rows
    sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
        excel.CellStyle(
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: isLastInBox
          ? excel.Border(borderStyle: excel.BorderStyle.Medium)
          : excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Product details in column D
    final type = product['type'] ?? 'Unknown';
    final weight = product['weight'] ?? 0;
    final flowerType = product['flowerType'] ?? 'LOOSE FLOWERS';
    final hasStems = product['hasStems'] ?? false;
    final approxQuantity = product['approxQuantity'] ?? 0;

    // Format: TYPE - WEIGHT KG (FLOWER TYPE, STEMS STATUS, APPROX QUANTITY)
    final stemsText = hasStems ? '' : 'NO STEMS';
    final productDetails =
        '• $type - ${weight}KG ($flowerType, $stemsText, APPROX $approxQuantity NOS)';

    sheet.cell(excel.CellIndex.indexByString('D$row')).value =
        excel.TextCellValue(productDetails);
    sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
        excel.CellStyle(
      fontSize: 10,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: isLastInBox
          ? excel.Border(borderStyle: excel.BorderStyle.Medium)
          : excel.Border(borderStyle: excel.BorderStyle.Thin),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in product row (B, C, E, F, G)
    for (String col in ['B', 'C', 'E', 'F', 'G']) {
      var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
      emptyCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: isLastInBox
            ? excel.Border(borderStyle: excel.BorderStyle.Medium)
            : excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add empty box row
  static void _addEmptyBoxRow(excel.Sheet sheet, int row) {
    // Empty cell in column A
    sheet.cell(excel.CellIndex.indexByString('A$row')).cellStyle =
        excel.CellStyle(
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Empty box message in column D
    sheet.cell(excel.CellIndex.indexByString('D$row')).value =
        excel.TextCellValue('• Empty Box');
    sheet.cell(excel.CellIndex.indexByString('D$row')).cellStyle =
        excel.CellStyle(
      fontSize: 10,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in empty box row (B, C, E, F, G)
    for (String col in ['B', 'C', 'E', 'F', 'G']) {
      var emptyCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
      emptyCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add separator row between boxes
  static void _addBoxSeparator(excel.Sheet sheet, int row) {
    // Add thin separator row for visual separation
    for (String col in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
      var separatorCell = sheet.cell(excel.CellIndex.indexByString('$col$row'));
      separatorCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add charges section
  static void _addChargesSection(
    excel.Sheet sheet,
    Map<String, dynamic> detailedData,
    int startRow,
  ) {
    // Charges header
    sheet.cell(excel.CellIndex.indexByString('D$startRow')).value =
        excel.TextCellValue('CHARGES');
    sheet.cell(excel.CellIndex.indexByString('D$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    sheet.cell(excel.CellIndex.indexByString('E$startRow')).value =
        excel.TextCellValue('RATE');
    sheet.cell(excel.CellIndex.indexByString('E$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    sheet.cell(excel.CellIndex.indexByString('F$startRow')).value =
        excel.TextCellValue('UNIT');
    sheet.cell(excel.CellIndex.indexByString('F$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    sheet.cell(excel.CellIndex.indexByString('G$startRow')).value =
        excel.TextCellValue('AMOUNT');
    sheet.cell(excel.CellIndex.indexByString('G$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in charges header row (A, B, C)
    for (String col in ['A', 'B', 'C']) {
      var emptyCell =
          sheet.cell(excel.CellIndex.indexByString('$col$startRow'));
      emptyCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }

    startRow++;

    double totalWeight = 0;
    double grandTotal = 0;
    Map<String, double> productTotals = {};
    Map<String, double> productRates = {};

    // Calculate totals
    if (detailedData['boxes'] != null) {
      for (var box in detailedData['boxes']) {
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
            productRates[productType] = rate;
          }
        }
      }
    }

    // Add product charges
    productTotals.forEach((productType, weight) {
      double rate = productRates[productType] ?? 0.0;
      double amount = rate * weight;
      grandTotal += amount;

      sheet.cell(excel.CellIndex.indexByString('D$startRow')).value =
          excel.TextCellValue(productType.toUpperCase());
      sheet.cell(excel.CellIndex.indexByString('D$startRow')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      sheet.cell(excel.CellIndex.indexByString('E$startRow')).value =
          excel.DoubleCellValue(rate);
      sheet.cell(excel.CellIndex.indexByString('E$startRow')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      sheet.cell(excel.CellIndex.indexByString('F$startRow')).value =
          excel.DoubleCellValue(weight);
      sheet.cell(excel.CellIndex.indexByString('F$startRow')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      sheet.cell(excel.CellIndex.indexByString('G$startRow')).value =
          excel.DoubleCellValue(amount);
      sheet.cell(excel.CellIndex.indexByString('G$startRow')).cellStyle =
          excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );

      // Add borders to empty cells in charges row (A, B, C)
      for (String col in ['A', 'B', 'C']) {
        var emptyCell =
            sheet.cell(excel.CellIndex.indexByString('$col$startRow'));
        emptyCell.cellStyle = excel.CellStyle(
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
      }

      startRow++;
    });

    // Gross Total
    sheet.cell(excel.CellIndex.indexByString('D$startRow')).value =
        excel.TextCellValue('Gross Total');
    sheet.cell(excel.CellIndex.indexByString('D$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    sheet.cell(excel.CellIndex.indexByString('F$startRow')).value =
        excel.DoubleCellValue(totalWeight);
    sheet.cell(excel.CellIndex.indexByString('F$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    sheet.cell(excel.CellIndex.indexByString('G$startRow')).value =
        excel.DoubleCellValue(grandTotal);
    sheet.cell(excel.CellIndex.indexByString('G$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in gross total row (A, B, C, E)
    for (String col in ['A', 'B', 'C', 'E']) {
      var emptyCell =
          sheet.cell(excel.CellIndex.indexByString('$col$startRow'));
      emptyCell.cellStyle = excel.CellStyle(
        bold: true,
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Add total in words section
  static void _addTotalInWords(
    excel.Sheet sheet,
    Map<String, dynamic> detailedData,
    int startRow,
  ) {
    // Calculate grand total
    double grandTotal = 0;

    if (detailedData['boxes'] != null) {
      for (var box in detailedData['boxes']) {
        if (box['products'] != null) {
          for (var product in box['products']) {
            double weight =
                double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
            double rate =
                double.tryParse(product['rate']?.toString() ?? '0') ?? 0.0;

            grandTotal += (weight * rate);
          }
        }
      }
    }

    startRow += 2;
    String totalInWords = _convertNumberToWords(grandTotal);
    sheet.cell(excel.CellIndex.indexByString('A$startRow')).value =
        excel.TextCellValue('Gross Total (in words): $totalInWords');
    sheet.cell(excel.CellIndex.indexByString('A$startRow')).cellStyle =
        excel.CellStyle(
      bold: true,
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
    );

    // Add borders to empty cells in total in words row (B, C, D, E, F, G)
    for (String col in ['B', 'C', 'D', 'E', 'F', 'G']) {
      var emptyCell =
          sheet.cell(excel.CellIndex.indexByString('$col$startRow'));
      emptyCell.cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
    }
  }

  /// Convert number to words
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

  /// Save Excel file to Downloads folder
  static Future<File> _saveExcelFile(
      String fileName, excel.Excel workbook) async {
    try {
      // Try to save to Downloads folder (most accessible on Android)
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        // Android: Try Downloads folder first
        try {
          // Using environment variable approach for Downloads
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Navigate to Downloads from external storage
            downloadsDir = Directory('${externalDir.path}/../../../Download');
            if (!downloadsDir.existsSync()) {
              downloadsDir = Directory(externalDir.path);
            }
          }
        } catch (e) {
          print('Could not access external storage: $e');
        }

        // Fallback to app documents directory
        if (downloadsDir == null || !downloadsDir.existsSync()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        // iOS: Use documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not determine save location');
      }

      // Create invoices subdirectory
      final invoicesDir = Directory('${downloadsDir.path}/Invoices');
      if (!invoicesDir.existsSync()) {
        invoicesDir.createSync(recursive: true);
      }

      // Save the file
      final filePath = '${invoicesDir.path}/$fileName';
      final excelFile = File(filePath);
      List<int>? excelBytes = workbook.encode();

      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      await excelFile.writeAsBytes(excelBytes);
      print('Excel file saved: $filePath');

      return excelFile;
    } catch (e) {
      print('Error saving Excel file: $e');
      rethrow;
    }
  }

  /// Add shipper address with grouped borders for AWB section
  /// Connects with the "Shipper:" header with proper top border
  static int _addShipperAddressGrouped(
      excel.Sheet sheet, String columnLetter, String address, int startRow) {
    if (address.isEmpty || address == 'Address') {
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(address);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      return startRow + 1;
    }

    // Split address by comma and trim whitespace
    List<String> addressParts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    // Add each part on a separate row, except combine last two parts
    if (addressParts.length <= 1) {
      // Single part - just add it
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(addressParts[0]);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    } else if (addressParts.length == 2) {
      // Two parts - combine them with " - "
      sheet
              .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
              .value =
          excel.TextCellValue('${addressParts[0]} - ${addressParts[1]}');
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    } else {
      // More than two parts - add all but last two separately, then combine last two
      for (int i = 0; i < addressParts.length - 2; i++) {
        sheet
            .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
            .value = excel.TextCellValue(addressParts[i]);
        sheet
            .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
            .cellStyle = excel.CellStyle(
          topBorder: i == 0
              ? excel.Border(borderStyle: excel.BorderStyle.Medium)
              : excel.Border(borderStyle: excel.BorderStyle.Thin),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        );
        startRow++;
      }
      // Combine last two parts
      String lastTwoCombined =
          '${addressParts[addressParts.length - 2]} - ${addressParts[addressParts.length - 1]}';
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .value = excel.TextCellValue(lastTwoCombined);
      sheet
          .cell(excel.CellIndex.indexByString('$columnLetter$startRow'))
          .cellStyle = excel.CellStyle(
        topBorder: addressParts.length == 3
            ? excel.Border(borderStyle: excel.BorderStyle.Medium)
            : excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Medium),
      );
      startRow++;
    }

    return startRow;
  }
}
