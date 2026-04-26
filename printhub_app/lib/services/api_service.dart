import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import '../models/print_job_model.dart';

class ApiService {
  // Your PC's local IP — phone must be on the same WiFi
  // Change to your hosted URL when deploying to internet
  static const String baseUrl = 'http://192.168.29.235:3000';

  // ============ AUTH ============
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return _handleResponse(response);
  }

  // ============ STUDENT ============
  static Future<Map<String, dynamic>> getWallet(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/student/wallet'),
      headers: _authHeaders(token),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadPDF(
      String token, File file, bool duplex) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload'),
    );
    request.headers.addAll(_authHeaders(token));
    request.fields['duplex'] = duplex.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'pdf',
      file.path,
      contentType: MediaType('application', 'pdf'),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // ============ ADMIN ============
  static Future<List<UserModel>> getStudents(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/students'),
      headers: _authHeaders(token),
    );
    final data = _handleResponse(response);
    if (data['error'] != null) throw Exception(data['error']);
    final List list = jsonDecode(response.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<List<PrintJobModel>> getPrintJobs(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/print-jobs'),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) throw Exception('Failed to load jobs');
    final List list = jsonDecode(response.body);
    return list.map((e) => PrintJobModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> addWallet(
      String token, String studentId, int amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/add-wallet'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(token),
      },
      body: jsonEncode({'studentId': studentId, 'amount': amount}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'));
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateSettings(
      String token, double pricePerPage) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/settings'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(token),
      },
      body: jsonEncode({'pricePerPage': pricePerPage}),
    );
    return _handleResponse(response);
  }

  // ============ HELPERS ============
  static Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } catch (_) {
      return {'error': 'Invalid server response'};
    }
  }
}
