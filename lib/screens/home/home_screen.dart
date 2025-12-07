import 'package:flutter/material.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/screens/drawer.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  final String signURL;

  HomeScreen({required this.signURL});

  final GlobalKey<InvoiceFormState> _formKey = GlobalKey<InvoiceFormState>();

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
              _previewInvoice(context, invoiceProvider);
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: InvoiceForm(key: _formKey),
    );
  }

  void _previewInvoice(
      BuildContext context, InvoiceProvider invoiceProvider) async {
    final formState = _formKey.currentState;
    if (formState != null) {
      final shipmentData = formState.getCurrentShipmentData();
      await invoiceProvider.previewInvoiceWithData(shipmentData);
    } else {
      await invoiceProvider.previewInvoice();
    }
  }
}
