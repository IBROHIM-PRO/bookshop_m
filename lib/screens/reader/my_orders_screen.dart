import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class MyOrdersScreen extends StatefulWidget {
  final bool showAppBar;
  const MyOrdersScreen({super.key, this.showAppBar = true});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('/api/orders/my');
      if (response.statusCode == 200) {
        setState(() {
          _orders = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Фармоишҳо ёфт нашуданд.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Хатогӣ дар пайвастшавӣ ба сервер.';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
      case 'approved':
        return Colors.teal;
      case 'rejected':
      case 'cancelled':
        return Colors.redAccent;
      case 'delivered':
        return Colors.lightGreen;
      default:
        return Colors.white54;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Дар интизор';
      case 'confirmed':
      case 'approved':
        return 'Тасдиқ шуд';
      case 'rejected':
        return 'Рад шуд';
      case 'cancelled':
        return 'Бекор шуд';
      case 'delivered':
        return 'Расид';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'delivered':
        return Icons.local_shipping_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      if (!widget.showAppBar) {
        return Center(child: CircularProgressIndicator(color: primaryColor));
      }
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final bodyWidget = Builder(builder: (context) {

      if (_error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: subTextColor)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: Text('Боз кӯшиш кунед', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
            ],
          ),
        );
      }

      if (_orders.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: textColor.withOpacity(0.2)),
              const SizedBox(height: 20),
              Text(
                'Шумо то ҳол ягон заявка надодаед',
                style: TextStyle(color: subTextColor, fontSize: 16),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _fetchOrders,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            final status = order['status'] ?? 'pending';
            final items = order['orderItems'] as List? ?? [];
            final date = order['dateCreated'] != null
                ? DateTime.tryParse(order['dateCreated'])
                : null;

            final isDarkMode = theme.brightness == Brightness.dark;
            final cardColor = isDarkMode ? theme.cardColor : Colors.white;
            final borderColor = isDarkMode ? theme.dividerColor : const Color(0xFF1E7431).withOpacity(0.15);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: isDarkMode ? [] : [
                  BoxShadow(
                    color: const Color(0xFF228B22).withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_outlined, color: subTextColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Заявка #${order['id']}',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon(status), color: _statusColor(status), size: 14),
                              const SizedBox(width: 5),
                              Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, thickness: 1, color: isDarkMode ? theme.dividerColor : const Color(0xFFE5EFE7)),

                  if (items.isNotEmpty)
                    ...items.map((item) {
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDarkMode ? primaryColor.withOpacity(0.1) : const Color(0xFFEBF3ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.book_outlined, color: isDarkMode ? primaryColor : const Color(0xFF1E7431), size: 18),
                        ),
                        title: Text(
                          item['bookTitle'] ?? (item['book'] != null ? item['book']['title'] : 'Китоб'),
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        trailing: Text(
                          '${item['quantity'] ?? 1} дона',
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      );
                    }),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (date != null)
                          Text(
                            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                            style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                          ),
                        Text(
                          'Ҷамъ: ${order['totalAmount'] ?? order['totalPrice'] ?? 0} TJS',
                          style: TextStyle(
                            color: isDarkMode ? primaryColor : const Color(0xFF1E7431),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });

    if (!widget.showAppBar) {
      return bodyWidget;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Заявкаҳои ман', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor.withOpacity(0.7)),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: bodyWidget,
    );
  }
}
