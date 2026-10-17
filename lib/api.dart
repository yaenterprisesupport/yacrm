import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kBaseUrl = 'https://crm.yatech.co.in/api';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => status == 403 ? 'Access restricted for your role' : message;
}

class Session {
  Session(this.id, this.name, this.role);
  final String id, name, role;
  Map<String, String> toJson() => {'id': id, 'name': name, 'role': role};
}

class Api {
  static Session? session;
  static Map<String, dynamic> _perm = {};

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (session != null) 'x-user-role': session!.role,
        if (session != null) 'x-user-id': session!.id,
        if (session != null) 'x-user-name': session!.name,
      };

  static Future<dynamic> send(String method, String path,
      {Object? body, Map<String, String>? q}) async {
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: q);
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 30)));
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = res.body;
    }
    if (res.statusCode >= 400) {
      final msg = data is Map
          ? (data['error'] ?? data['message'] ?? 'Request failed').toString()
          : 'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }

  static Future<dynamic> get(String p, {Map<String, String>? q}) => send('GET', p, q: q);
  static Future<dynamic> post(String p, [Object? b]) => send('POST', p, body: b ?? {});

  /// Accepts a bare list or an envelope like {data: [...]}.
  static List<Map<String, dynamic>> asList(dynamic d) {
    if (d is Map) {
      d = d['data'] ?? d['items'] ?? d.values.firstWhere((v) => v is List, orElse: () => []);
    }
    return d is List
        ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
  }

  static Future<void> login(String user, String password) async {
    final d = await send('POST', '/auth/login', body: {'email': user, 'password': password});
    final m = d is Map ? d : <String, dynamic>{};
    if (m['success'] == false) {
      throw ApiException(401, (m['error'] ?? m['message'] ?? 'Login failed').toString());
    }
    final u = (m['user'] ?? m['employee'] ?? m) as Map;
    String pick(List<String> keys, String fallback) {
      for (final k in keys) {
        final v = u[k] ?? m[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    final role = pick(['role'], 'employee').toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    session = Session(pick(['employeeId', 'id', 'userId'], user),
        pick(['name', 'fullName', 'username'], user), role);
    try {
      (await SharedPreferences.getInstance()).setString('session', jsonEncode(session!.toJson()));
    } catch (_) {} // storage is optional: login still works if it fails
    await loadPermissions();
  }

  static Future<bool> restore() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString('session');
      if (s == null) return false;
      final m = jsonDecode(s) as Map;
      session = Session(m['id'] as String, m['name'] as String, m['role'] as String);
    } catch (_) {
      return false;
    }
    await loadPermissions();
    return true;
  }

  static Future<void> logout() async {
    session = null;
    _perm = {};
    try {
      await (await SharedPreferences.getInstance()).remove('session');
    } catch (_) {}
  }

  static Future<void> loadPermissions() async {
    try {
      _perm = Map<String, dynamic>.from(await get('/permissions') as Map);
    } catch (_) {
      _perm = {};
    }
  }

  /// WRITE / READ / NONE — user override first, then role default.
  static String access(String module) {
    final s = session;
    if (s == null) return 'NONE';
    String? pick(dynamic root, String who) {
      final x = root is Map ? root[who] : null;
      final mod = x is Map ? x[module] : null;
      return mod is Map ? mod['access']?.toString().toUpperCase() : null;
    }

    return pick(_perm['userPermissions'], s.id) ??
        pick(_perm['rolePermissions'], s.role) ??
        (_perm.isEmpty
            ? (s.role == 'employee' && module != 'employee-portal' ? 'NONE' : 'WRITE')
            : 'NONE');
  }
}
