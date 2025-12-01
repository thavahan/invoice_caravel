import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';

class ConnectivityStatusWidget extends StatefulWidget {
  const ConnectivityStatusWidget({super.key});

  @override
  State<ConnectivityStatusWidget> createState() =>
      _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  Map<String, dynamic>? _dataSourceInfo;
  bool _isVisible = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDataSourceInfo();
  }

  Future<void> _loadDataSourceInfo() async {
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final invoiceProvider =
          Provider.of<InvoiceProvider>(context, listen: false);
      final info = await invoiceProvider.getDataSourceInfo();
      if (mounted) {
        setState(() {
          _dataSourceInfo = info;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to trigger rebuilds
    context.watch<InvoiceProvider>();

    // Load data source info when widget builds (triggered by provider changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isRefreshing) {
        _loadDataSourceInfo();
      }
    });

    if (_dataSourceInfo == null || !_isVisible) {
      return const SizedBox.shrink();
    }

    final isOnline = _dataSourceInfo!['isOnline'] as bool;
    final forceOffline = _dataSourceInfo!['forceOffline'] as bool;

    // Only show if offline or forced offline
    if (isOnline && !forceOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: forceOffline ? Colors.orange.shade100 : Colors.red.shade100,
      child: Row(
        children: [
          Icon(
            forceOffline ? Icons.wifi_off : Icons.wifi_off,
            color: forceOffline ? Colors.orange.shade800 : Colors.red.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              forceOffline
                  ? 'Offline Mode (Forced) - Using Local Database'
                  : 'Offline - Using Local Database',
              style: TextStyle(
                color:
                    forceOffline ? Colors.orange.shade800 : Colors.red.shade800,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _isRefreshing ? null : _loadDataSourceInfo,
            child: _isRefreshing
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        forceOffline
                            ? Colors.orange.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  )
                : Text(
                    'Refresh',
                    style: TextStyle(
                      color: forceOffline
                          ? Colors.orange.shade800
                          : Colors.red.shade800,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _isVisible = false;
              });
            },
            icon: Icon(
              Icons.close,
              color:
                  forceOffline ? Colors.orange.shade800 : Colors.red.shade800,
              size: 20,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Hide',
          ),
        ],
      ),
    );
  }
}
