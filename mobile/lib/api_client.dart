import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

  final String baseUrl;

  Future<List<Map<String, dynamic>>> tasks() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/tasks'));
    return _list(response);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/notifications'));
    return _list(response);
  }

  Future<void> createWeatherTask({
    required String name,
    required double latitude,
    required double longitude,
    required String scheduleTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'type': 'weather',
        'timezone': 'Asia/Shanghai',
        'schedule_time': scheduleTime,
        'config': {
          'latitude': latitude,
          'longitude': longitude,
          'start_hour': 8,
          'end_hour': 19,
          'precipitation_probability_gt': 0,
        },
      }),
    );
    _ensureOk(response);
  }

  Future<void> registerDevice({required String platform, required String registrationId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/devices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'platform': platform, 'registration_id': registrationId, 'push_provider': 'jpush'}),
    );
    _ensureOk(response);
  }

  Future<void> toggleTask(Map<String, dynamic> task, bool enabled) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/tasks/${task['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'enabled': enabled}),
    );
    _ensureOk(response);
  }

  Future<Map<String, dynamic>> checkUpdate(String currentVersion) async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/app/version/check?version=$currentVersion'));
    _ensureOk(response);
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  List<Map<String, dynamic>> _list(http.Response response) {
    _ensureOk(response);
    return (jsonDecode(response.body) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('请求失败 (${response.statusCode})：${response.body}');
    }
  }
}
