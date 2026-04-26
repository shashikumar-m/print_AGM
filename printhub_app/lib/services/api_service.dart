import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import '../models/print_job_model.dart';
import '../models/settings_model.dart';
import '../models/section_model.dart';
import '../models/printer_location_model.dart';

class ApiService {
  static const String baseUrl = 'https://print-agm.onrender.com';

  // ── AUTH ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}))
        .timeout(const Duration(seconds: 30));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password, String section) async {
    final r = await http.post(Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password, 'section': section}))
        .timeout(const Duration(seconds: 30));
    return _handle(r);
  }

  // ── PRINTER LOCATIONS ─────────────────────────────────────────────────────
  static Future<List<PrinterLocationModel>> getPrinterLocations() async {
    final r = await http.get(Uri.parse('$baseUrl/api/printer-locations'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final List list = jsonDecode(r.body);
    return list.map((e) => PrinterLocationModel.fromJson(e)).toList();
  }

  static Future<List<PrinterLocationModel>> getAdminPrinterLocations(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/api/admin/printer-locations'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final List list = jsonDecode(r.body);
    return list.map((e) => PrinterLocationModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> createPrinterLocation(
      String token, String name, String description) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/printer-locations'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode({'name': name, 'description': description}))
        .timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> deletePrinterLocation(
      String token, String id) async {
    final r = await http.delete(
        Uri.parse('$baseUrl/api/admin/printer-locations/$id'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> assignPrinterToSection(
      String token, String sectionId, String printerId) async {
    final r = await http.post(
        Uri.parse('$baseUrl/api/admin/sections/$sectionId/assign-printer'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode({'printerId': printerId}))
        .timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> assignPrinterToUser(
      String token, String userId, String printerId) async {
    final r = await http.post(
        Uri.parse('$baseUrl/api/admin/users/$userId/assign-printer'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode({'printerId': printerId}))
        .timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  // ── SECTIONS ──────────────────────────────────────────────────────────────
  static Future<List<SectionModel>> getSections() async {
    final r = await http.get(Uri.parse('$baseUrl/api/sections'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final List list = jsonDecode(r.body);
    return list.map((e) => SectionModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> createSection(String token, String name) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/sections'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode({'name': name}))
        .timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> deleteSection(String token, String id) async {
    final r = await http.delete(Uri.parse('$baseUrl/api/admin/sections/$id'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  // ── UPLOAD ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadPDF(
      String token, File file, Map<String, String> printOptions) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
    request.headers.addAll(_auth(token));
    request.fields.addAll(printOptions);
    request.files.add(await http.MultipartFile.fromPath('pdf', file.path,
        contentType: MediaType('application', 'pdf')));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final r = await http.Response.fromStream(streamed);
    return _handle(r);
  }

  // ── STUDENT ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWallet(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/api/student/wallet'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  // ── ADMIN ─────────────────────────────────────────────────────────────────
  static Future<List<UserModel>> getStudents(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/api/admin/students'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Failed to load students');
    final List list = jsonDecode(r.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> createStudent(
      String token, Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/students'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<List<UserModel>> getFaculty(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/api/admin/faculty'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Failed to load faculty');
    final List list = jsonDecode(r.body);
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> createFaculty(
      String token, Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/faculty'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode(data)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  static Future<List<PrintJobModel>> getPrintJobs(String token) async {
    final r = await http.get(Uri.parse('$baseUrl/api/admin/print-jobs'),
        headers: _auth(token)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Failed to load jobs');
    final List list = jsonDecode(r.body);
    return list.map((e) => PrintJobModel.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> addWallet(
      String token, String studentId, int amount) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/add-wallet'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode({'studentId': studentId, 'amount': amount}))
        .timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  // ── SETTINGS ──────────────────────────────────────────────────────────────
  static Future<SettingsModel> getSettings() async {
    final r = await http.get(Uri.parse('$baseUrl/api/settings'))
        .timeout(const Duration(seconds: 15));
    try { return SettingsModel.fromJson(jsonDecode(r.body)); }
    catch (_) { return const SettingsModel(); }
  }

  static Future<Map<String, dynamic>> updateSettings(
      String token, Map<String, dynamic> settings) async {
    final r = await http.post(Uri.parse('$baseUrl/api/admin/settings'),
        headers: {'Content-Type': 'application/json', ..._auth(token)},
        body: jsonEncode(settings)).timeout(const Duration(seconds: 15));
    return _handle(r);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  static Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  static Map<String, dynamic> _handle(http.Response r) {
    try {
      final data = jsonDecode(r.body);
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } catch (_) {
      return {
        'error': 'Invalid server response (HTTP ${r.statusCode})',
        'raw': r.body.length > 300 ? r.body.substring(0, 300) : r.body,
      };
    }
  }
}
