import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';

class PdfReaderScreen extends StatefulWidget {
  final Book book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  bool _isLoading = true;
  String? _error;
  String? _localFilePath;
  double _downloadProgress = 0.0;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    if (widget.book.pdfUrl == null || widget.book.pdfUrl!.isEmpty) {
      setState(() {
        _error = 'Суроғаи PDF барои ин китоб вуҷуд надорад.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _downloadProgress = 0.0;
      _currentPageIndex = 0;
    });

    try {
      // 1. Request access ticket from backend
      final ticketResponse = await ApiService.post(
        '/api/books/${widget.book.id}/request-ticket',
        {},
      );

      if (ticketResponse.statusCode != 200) {
        String msg = 'Дастрасӣ маҳдуд аст ё хатогӣ дар пайвастшавӣ.';
        if (ticketResponse.body.isNotEmpty) {
          try {
            final errData = jsonDecode(ticketResponse.body);
            if (errData['message'] != null) {
              msg = errData['message'];
            }
          } catch (_) {}
        }
        setState(() {
          _error = msg;
          _isLoading = false;
        });
        return;
      }

      final ticketData = jsonDecode(ticketResponse.body);
      final ticket = ticketData['ticket'];

      // 2. Setup full URL with ticket
      final pdfUri = Uri.parse('${widget.book.pdfUrl}?ticket=$ticket');

      // 3. Get Auth Token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 4. Download file bytes with Referer bypass
      final client = http.Client();
      final request = http.Request('GET', pdfUri);
      
      request.headers['Referer'] = 'http://localhost';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await client.send(request);

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Хатогӣ ҳангоми гирифтани файл аз сервер: ${response.statusCode}';
          _isLoading = false;
        });
        return;
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      
      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0) {
          setState(() {
            _downloadProgress = bytes.length / contentLength;
          });
        }
      }

      // 5. Save locally in temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/book_${widget.book.id}.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _localFilePath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Хатогӣ ҳангоми боргирии китоб: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBw = Provider.of<ThemeProvider>(context).isBlackAndWhite;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final bgColor = isBw ? Colors.black : const Color(0xFF0F0C20);
    final textColor = isBw ? Colors.white : Colors.white.withOpacity(0.9);
    final appBarColor = isBw ? Colors.black : const Color(0xFF15102A);

    Widget body;

    if (_isLoading) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                color: primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                _downloadProgress > 0
                    ? 'Боргирии китоб: ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                    : 'Пайвастшавӣ ба сервер...',
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Боз кӯшиш кунед'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: isBw ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = PdfDocumentViewBuilder.file(
        _localFilePath!,
        builder: (context, document) {
          if (document == null) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }
          return Stack(
            children: [
              PageView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: document.pages.length,
                onPageChanged: (pageIndex) {
                  setState(() {
                    _currentPageIndex = pageIndex;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    maxScale: 4.0,
                    minScale: 1.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: PdfPageView(
                          document: document,
                          pageNumber: index + 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      'Саҳифаи ${_currentPageIndex + 1} аз ${document.pages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.book.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: body,
    );
  }
}
