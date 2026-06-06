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
  @override
  Widget build(BuildContext context) {
    final bodyWidget = Builder(builder: (context) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
      }

      if (_error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.redAccent.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                child: const Text('Боз кӯшиш кунед', style: TextStyle(color: Colors.white)),
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
              Icon(Icons.receipt_long_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
              const SizedBox(height: 20),
              Text(
                'Шумо то ҳол ягон заявка надодаед',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _fetchOrders,
        color: Colors.deepPurpleAccent,
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

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                            const Icon(Icons.receipt_outlined, color: Colors.white54, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Заявка #${order['id']}',
                              style: const TextStyle(
                                color: Colors.white,
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

                  const Divider(height: 1, thickness: 1, color: Color(0xFF1E1A35)),

                  if (items.isNotEmpty)
                    ...items.map((item) {
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.book_outlined, color: Colors.deepPurpleAccent, size: 18),
                        ),
                        title: Text(
                          item['bookTitle'] ?? (item['book'] != null ? item['book']['title'] : 'Китоб'),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        trailing: Text(
                          '${item['quantity'] ?? 1} дона',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
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
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        Text(
                          'Ҷамъ: ${order['totalPrice'] ?? 0} TJS',
                          style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF15102A),
        elevation: 0,
        title: const Text('Заявкаҳои ман', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: bodyWidget,
    );
  }
}
