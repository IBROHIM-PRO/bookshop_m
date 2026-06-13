import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart' show VoidCallback;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static VoidCallback? onUnauthorized;

  static const List<String> candidateHosts = [
    '192.168.0.100:5179',
    'localhost:5179',
    '10.0.2.2:5179',
    '10.74.7.83:5179',
  ];
  static int _currentHostIndex = 0;

  static String get serverHost => candidateHosts[_currentHostIndex];

  static void switchHost() {
    _currentHostIndex = (_currentHostIndex + 1) % candidateHosts.length;
    debugPrint('Switched to host: $serverHost');
  }

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://$serverHost';
    }
    return 'http://$serverHost';
  }

  static String get wsBaseUrl {
    if (kIsWeb) {
      return 'ws://$serverHost';
    }
    return 'ws://$serverHost';
  }

  static void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> _runWithFailover(
    Future<http.Response> Function(String urlPrefix) requestFn,
  ) async {
    int startIndex = _currentHostIndex;
    int attempts = 0;
    while (attempts < candidateHosts.length) {
      int idx = (startIndex + attempts) % candidateHosts.length;
      String currentBaseUrl = 'http://${candidateHosts[idx]}';
      try {
        final response = await requestFn(currentBaseUrl);
        if (_currentHostIndex != idx) {
          _currentHostIndex = idx;
          debugPrint('Switched active host to: ${candidateHosts[idx]}');
        }
        return response;
      } catch (e) {
        attempts++;
        debugPrint(
          'Request error on ${candidateHosts[idx]}: $e. Attempts: $attempts/${candidateHosts.length}',
        );
        if (attempts >= candidateHosts.length) {
          rethrow;
        }
      }
    }
    throw Exception('All hosts failed');
  }

  static Future<http.Response> get(String endpoint) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final headers = await _getHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final headers = await _getHeaders();
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 5));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> postWithTimeout(
    String endpoint,
    Map<String, dynamic> body,
    Duration timeout,
  ) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final headers = await _getHeaders();
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final headers = await _getHeaders();
      final response = await http
          .put(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 5));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> delete(String endpoint) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final headers = await _getHeaders();
      final response = await http
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 5));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> uploadFile(
    String filePath,
    String fileName,
  ) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix/api/StaticFile');
      final request = http.MultipartRequest('POST', url);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        await http.MultipartFile.fromPath('File', filePath, filename: fileName),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> uploadAvatar(
    String filePath,
    String fileName, {
    int? userId,
  }) async {
    return _runWithFailover((urlPrefix) async {
      final endpoint = userId != null
          ? '/api/auth/users/$userId/avatar'
          : '/api/auth/profile/avatar';
      final url = Uri.parse('$urlPrefix$endpoint');
      final request = http.MultipartRequest('POST', url);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));
      _checkResponse(response);
      return response;
    });
  }

  static Future<http.Response> sendMultipart({
    required String endpoint,
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    String? fileName,
  }) async {
    return _runWithFailover((urlPrefix) async {
      final url = Uri.parse('$urlPrefix$endpoint');
      final request = http.MultipartRequest('POST', url);
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      if (fileField != null && filePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            fileField,
            filePath,
            filename: fileName,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));
      _checkResponse(response);
      return response;
    });
  }

  static String getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) {
      try {
        final currentUri = Uri.parse(baseUrl);
        final urlUri = Uri.parse(url);
        final host = urlUri.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
          return urlUri
              .replace(
                scheme: currentUri.scheme,
                host: currentUri.host,
                port: currentUri.port,
              )
              .toString();
        }
      } catch (_) {}
      return url;
    }
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    return '$baseUrl$cleanUrl';
  }
}
