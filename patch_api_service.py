import sys

with open('lib/services/api_service.dart', 'r') as f:
    content = f.read()

import re

old_runWithFailover = """  static Future<http.Response> _runWithFailover(Future<http.Response> Function() requestFn) async {
    int attempts = 0;
    while (attempts < candidateHosts.length) {
      try {
        return await requestFn();
      } catch (e) {
        attempts++;
        debugPrint('Request error on $serverHost: $e. Attempts: $attempts/${candidateHosts.length}');
        if (attempts >= candidateHosts.length) {
          rethrow;
        }
        switchHost();
      }
    }
    throw Exception('All hosts failed');
  }"""

new_runWithFailover = """  static Future<http.Response> _runWithFailover(Future<http.Response> Function(String urlPrefix) requestFn) async {
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
        debugPrint('Request error on ${candidateHosts[idx]}: $e. Attempts: $attempts/${candidateHosts.length}');
        if (attempts >= candidateHosts.length) {
          rethrow;
        }
      }
    }
    throw Exception('All hosts failed');
  }"""

content = content.replace(old_runWithFailover, new_runWithFailover)

# Replace methods to use urlPrefix
content = content.replace("    return _runWithFailover(() async {\n      final url = Uri.parse('$baseUrl$endpoint');", 
                          "    return _runWithFailover((urlPrefix) async {\n      final url = Uri.parse('$urlPrefix$endpoint');")

# Specifically for uploadFile
content = content.replace("    return _runWithFailover(() async {\n      final url = Uri.parse('$baseUrl/api/StaticFile');",
                          "    return _runWithFailover((urlPrefix) async {\n      final url = Uri.parse('$urlPrefix/api/StaticFile');")

# Specifically for uploadAvatar
content = content.replace("    return _runWithFailover(() async {\n      final endpoint = userId != null ? '/api/auth/users/$userId/avatar' : '/api/auth/profile/avatar';\n      final url = Uri.parse('$baseUrl$endpoint');",
                          "    return _runWithFailover((urlPrefix) async {\n      final endpoint = userId != null ? '/api/auth/users/$userId/avatar' : '/api/auth/profile/avatar';\n      final url = Uri.parse('$urlPrefix$endpoint');")

with open('lib/services/api_service.dart', 'w') as f:
    f.write(content)

print("Patched!")
