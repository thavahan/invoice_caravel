import 'package:flutter/material.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/screens/drawer.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  final String signURL;

  HomeScreen({required this.signURL});

  @override
  Widget build(BuildContext context) {
    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    return Scaffold(
      drawer: AppDrawer(signURL),
      appBar: AppBar(
        title: const Text('Invoice Generator'),
        actions: [
          IconButton(
            onPressed: () {
              invoiceProvider.shareInvoice();
            },
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: () {
              invoiceProvider.previewInvoice();
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: InvoiceForm(),
    );
  }
}
