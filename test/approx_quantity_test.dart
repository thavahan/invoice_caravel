import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';

void main() {
  testWidgets('Approx quantity field renders correctly', (WidgetTester tester) async {
    // Create a test invoice form
    final invoiceForm = MaterialApp(
      home: Scaffold(
        body: InvoiceForm(),
      ),
    );

    await tester.pumpWidget(invoiceForm);
    await tester.pumpAndSettle();

    // Test that the approx quantity field exists
    expect(find.text('Approx.Quantity'), findsOneWidget);

    // Test that we can find TextFormField widgets (indicating the form rendered)
    expect(find.byType(TextFormField), findsWidgets);

    print('✅ Approx quantity field test passed - form renders correctly with approx quantity field');
  });
}