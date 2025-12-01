import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/pdf_service.dart';
import '../models/product.dart';
import '../models/shipment.dart';

class PastOrders extends StatefulWidget {
  PastOrders({
    required this.signURL,
  });
  static const routeName = '/past';

  final String signURL;

  @override
  State<PastOrders> createState() => _PastOrdersState();
}

class _PastOrdersState extends State<PastOrders> {
  final db = FirebaseFirestore.instance;
  final DateTime date = DateTime.now();

  void setErrorBuilder() {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return Scaffold(
          body: Center(
              child: Container(
        height: 5000,
        child: SingleChildScrollView(
          child: Column(
            children: [
              //  Text(errorDetails.stack.toString()),
              Text(errorDetails.summary.toString()),
              // Text(errorDetails.toString()),
            ],
          ),
        ),
      )));
    };
  }

  List<String> paths = [];
  Future<bool> getData() async {
    var response = await http.get(Uri.parse(
        'https://invoice-caravel-default-rtdb.firebaseio.com/past-order.json'));

    var link = json.decode(response.body);
    link.entries.forEach((element) {
      paths.add((element.value['path']));
    });
    return true;
  }

  var myF;
  @override
  void initState() {
    setErrorBuilder();
    myF = getData();
    super.initState();
  }

  String decodeText(String x) {
    String decoded = utf8.decode(base64.decode(x));
    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Past Invoices'),
        ),
        body: FutureBuilder(
          future: myF,
          builder: (context, snapshot) =>
              snapshot.connectionState == ConnectionState.waiting
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Column(children: [
                          for (int i = 0; i < paths.length; i++) ...[
                            Orders(
                              signURL: widget.signURL,
                              paths: paths,
                              i: i,
                            )
                          ],
                        ]),
                      ),
                    ),
        ));
  }
}

class Orders extends StatefulWidget {
  Orders({required this.signURL, required this.paths, required this.i});
  final List<String> paths;
  final int i;
  final signURL;
  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final db = FirebaseFirestore.instance;
  final DateTime date = DateTime.now();
  var datas;
  List<Map<String, String>> invoiceP = [];

  void setErrorBuilder() {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return Scaffold(
          body: Center(
              child: Container(
        height: 5000,
        child: SingleChildScrollView(
          child: Column(
            children: [
              //  Text(errorDetails.stack.toString()),
              // Text(errorDetails.summary.toString()),
              Text(errorDetails.toString()),
            ],
          ),
        ),
      )));
    };
  }

  String decodeText(String x) {
    String decoded = utf8.decode(base64.decode(x));
    return decoded;
  }

  Future<bool> dataLoader() async {
    print('Data loader running');
    datas = await db.collection(widget.paths[widget.i]).get();
    for (int i = 0; i < datas.docs.length; i++) {
      var d = datas.docs[i];
      final Map<String, String> e = {
        'name': d["name"],
        'quantity': d["quantity"],
        'type': d["type"],
        'bonus': d["bonus"],
        'price': d["price"],
        'pack': d["pack"]
      };
      invoiceP.add(e);
    }
    return true;
  }

  var myF;
  @override
  void initState() {
    setErrorBuilder();
    myF = dataLoader();
    super.initState();
  }

  String getDate(String p) {
    DateTime data = DateTime.parse(p);
    var formatted = DateFormat.MMMd().format(data);
    return formatted;
  }

  Future<void> _generatePdf(bool isPreview) async {
    try {
      // Parse customer info from the path
      final pathData = decodeText(widget.paths[widget.i]).split('|');
      final customerData = pathData[1].split('-');
      final invoiceNumber = pathData[0];
      final invoiceDate = DateTime.parse(pathData[2]);

      // Create shipment object for the invoice
      final shipment = Shipment(
        invoiceNumber: invoiceNumber,
        shipper: 'Legacy Shipper',
        consignee: customerData[0],
        awb: invoiceNumber,
        flightNo: 'TBD',
        dischargeAirport: customerData.length > 1 ? customerData[1] : 'TBD',
        eta: invoiceDate.add(Duration(days: 1)),
        totalAmount: invoiceP.fold(0.0, (sum, item) {
          final price = double.tryParse(item['price'] ?? '0') ?? 0.0;
          final qty = int.tryParse(item['quantity'] ?? '0') ?? 0;
          return sum + (price * qty);
        }),
        invoiceTitle: 'Legacy Invoice $invoiceNumber',
        boxIds: [],
      );

      // Convert invoice items to new structure
      final items = invoiceP.map((item) {
        return Item(
          id: '',
          flowerTypeId: item['type'] ?? 'legacy',
          weightKg: double.tryParse(item['price'] ?? '0') ?? 0.0 / 10.0,
          form: item['name'] ?? '',
          quantity: int.tryParse(item['quantity'] ?? '0') ?? 0,
          notes: 'Legacy: ${item['pack'] ?? ''}',
        );
      }).toList();

      // Generate PDF
      final pdfService = PdfService();
      await pdfService.generateShipmentPDF(shipment, items, isPreview);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
      );
    }
  }

  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
        future: myF,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AnimatedContainer(
              color: Colors.brown.shade200,
              width: double.infinity,
              alignment: Alignment.center,
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: EdgeInsets.all(10),
              child: Text(
                'Loading...',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            );
          } else
            return AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    Card(
                      color: Colors.brown.shade200,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            expanded = !expanded;
                          });
                        },
                        child: ListTile(
                          style: ListTileStyle.drawer,
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'H${decodeText(widget.paths[widget.i]).split('|')[0]}',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                getDate(decodeText(widget.paths[widget.i])
                                    .split('|')[2]),
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          title: Text(
                            '${decodeText(widget.paths[widget.i]).split('|')[1].split('-')[0]}',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          trailing: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: 100,
                            child: Row(
                              children: [
                                IconButton(
                                    onPressed: () {
                                      _generatePdf(true);
                                    },
                                    icon: const Icon(Icons.picture_as_pdf)),
                                IconButton(
                                    onPressed: () {
                                      _generatePdf(false);
                                    },
                                    icon: const Icon(Icons.share)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                        // decoration: expanded
                        //     ? BoxDecoration(
                        //         border: Border.all(color: Colors.grey, width: 1))
                        //     : null,
                        duration: Duration(milliseconds: 200),
                        height: expanded ? datas.docs.length * 50.00 : 0,
                        child: ListView.builder(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: datas.docs.length,
                          itemBuilder: (context, index) {
                            return Card(
                              child: ListTile(
                                style: ListTileStyle.drawer,
                                visualDensity:
                                    VisualDensity(horizontal: 0, vertical: -4),
                                title: Text(datas.docs[index]["name"]),
                                leading: CircleAvatar(
                                    radius: 15,
                                    child: Text(datas.docs[index]["quantity"])),
                              ),
                            );
                          },
                        ))
                  ],
                ));
        });
  }
}
