import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taara/config/env.dart';
import 'package:taara/models/diagnostic_model.dart';

/// Erreur renvoyée par l'API TAARA (message déjà lisible pour l'utilisateur).
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Utilisateur connecté (sous-ensemble renvoyé par /auth/login).
class TaaraUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String userType; // CLIENT | PRO | ADMIN

  const TaaraUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.userType,
  });

  bool get isPro => userType == 'PRO';
  String get fullName => '$firstName $lastName'.trim();

  factory TaaraUser.fromJson(Map<String, dynamic> json) => TaaraUser(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        userType: json['userType'] ?? 'CLIENT',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'userType': userType,
      };
}

/// Client HTTP du backend TAARA (marketplace des réparateurs).
///
/// Le diagnostic reste 100 % local (Gemma / cache / base embarquée) ; l'API
/// sert à trouver un pro, suivre ses demandes et discuter avec lui.
/// Les jetons sont stockés dans SharedPreferences et rafraîchis
/// automatiquement sur un 401.
class ApiService {
  static const String _sessionKey = 'taara_session';
  static const Duration _timeout = Duration(seconds: 20);

  static String? _accessToken;
  static String? _refreshToken;
  static TaaraUser? _user;
  static bool _loaded = false;
  static Future<bool>? _refreshing;

  /// Notifie l'UI des connexions / déconnexions.
  static final ValueNotifier<TaaraUser?> currentUser = ValueNotifier(null);

  static TaaraUser? get user => _user;
  static bool get isLoggedIn => _accessToken != null && _user != null;

  // ── Session ───────────────────────────────────────────────────────────────

  static Future<void> loadSession() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _accessToken = map['accessToken'];
      _refreshToken = map['refreshToken'];
      _user = map['user'] != null ? TaaraUser.fromJson(Map<String, dynamic>.from(map['user'])) : null;
      currentUser.value = _user;
    } catch (e) {
      debugPrint('ApiService.loadSession error: $e');
    }
  }

  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'accessToken': _accessToken,
          'refreshToken': _refreshToken,
          'user': _user?.toJson(),
        }),
      );
    }
    currentUser.value = _user;
  }

  static Future<void> _applyAuthResponse(Map<String, dynamic> data) async {
    _accessToken = data['accessToken'];
    _refreshToken = data['refreshToken'];
    _user = TaaraUser.fromJson(Map<String, dynamic>.from(data['user']));
    await _saveSession();
  }

  static Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _saveSession();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<TaaraUser> login(String email, String password) async {
    final data = await _request('POST', '/auth/login',
        body: {'email': email.trim(), 'password': password}, auth: false);
    await _applyAuthResponse(data);
    return _user!;
  }

  static Future<TaaraUser> register({
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    bool asPro = false,
  }) async {
    final data = await _request('POST', '/auth/register',
        body: {
          'email': email.trim(),
          'phone': phone.replaceAll(' ', ''),
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'password': password,
          if (asPro) 'userType': 'PRO',
        },
        auth: false);
    await _applyAuthResponse(data);
    return _user!;
  }

  static Future<void> forgotPassword(String email) async {
    await _request('POST', '/auth/forgot-password',
        body: {'email': email.trim()}, auth: false);
  }

  static Future<void> logout() async {
    final refresh = _refreshToken;
    if (refresh != null) {
      try {
        await _request('POST', '/auth/logout', body: {'refreshToken': refresh});
      } catch (_) {
        // On déconnecte localement même si le serveur est injoignable
      }
    }
    await _clearSession();
  }

  // ── Professionnels ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchProfessionals({
    String? specialty,
    String? zone,
    String? q,
  }) async {
    final data = await _request('GET', '/professionals/search',
        query: {
          if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
          if (zone != null && zone.isNotEmpty) 'zone': zone,
          if (q != null && q.isNotEmpty) 'q': q,
          'perPage': '50',
        },
        auth: false);
    return _list(data['items']);
  }

  // ── Diagnostics & jobs ────────────────────────────────────────────────────

  /// Enregistre côté serveur un diagnostic produit sur l'appareil
  /// (nécessaire pour créer une demande auprès d'un pro).
  static Future<String> uploadDiagnostic(DiagnosticModel d, {String? description}) async {
    final text = (description != null && description.trim().length >= 5)
        ? description.trim()
        : '${d.objectName} — ${d.problem}';
    final data = await _request('POST', '/diagnostics', body: {
      'problemDescription': text.length > 2000 ? text.substring(0, 2000) : text,
      'problemType': d.objectName.length > 100 ? d.objectName.substring(0, 100) : d.objectName,
      'aiDiagnosis': d.toMap(),
      'confidence': d.confidence.clamp(0.0, 1.0),
    });
    return data['id'] as String;
  }

  static Future<Map<String, dynamic>> createJob({
    required String diagnosticId,
    required String professionalId,
    required double estimatedPrice,
    String? description,
  }) async {
    final data = await _request('POST', '/jobs', body: {
      'diagnosticId': diagnosticId,
      'professionalId': professionalId,
      'estimatedPrice': estimatedPrice,
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> myRequests() async =>
      _list(await _request('GET', '/jobs/my-requests'));

  static Future<List<Map<String, dynamic>>> myAssignedJobs() async =>
      _list(await _request('GET', '/jobs/my-assigned'));

  static Future<void> cancelJob(String id) => _request('PUT', '/jobs/$id/cancel');

  static Future<void> acceptJob(String id, double quotedPrice) =>
      _request('PUT', '/jobs/$id/accept', body: {'quotedPrice': quotedPrice});

  static Future<void> declineJob(String id, {String? reason}) => _request('PUT', '/jobs/$id/decline',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason});

  static Future<void> startJob(String id) => _request('PUT', '/jobs/$id/start');

  static Future<void> completeJob(String id, double actualPrice) =>
      _request('PUT', '/jobs/$id/complete', body: {'actualPrice': actualPrice});

  static Future<void> rateJob(String jobId, int score, {String? comment}) =>
      _request('POST', '/ratings', body: {
        'jobId': jobId,
        'score': score,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });

  /// Paiement en espèces (le paiement Mobile Money / Stripe passe par /payments).
  static Future<void> payCash(String jobId) =>
      _request('POST', '/payments', body: {'jobId': jobId, 'method': 'CASH'});

  // ── Messages ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> messages(String jobId) async {
    final data = await _request('GET', '/jobs/$jobId/messages', query: {'perPage': '100'});
    return _list(data['items']);
  }

  static Future<void> sendMessage(String jobId, String content) =>
      _request('POST', '/jobs/$jobId/messages', body: {'content': content});

  static Future<void> markMessagesRead(String jobId) async {
    try {
      await _request('PUT', '/jobs/$jobId/messages/read');
    } catch (_) {}
  }

  // ── Bas niveau ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _list(dynamic data) =>
      (data as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    bool retried = false,
  }) async {
    await loadSession();
    if (auth && _accessToken == null) {
      throw const ApiException('Connectez-vous pour continuer', statusCode: 401);
    }

    final uri = Uri.parse('${Env.apiBaseUrl}$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
    final encoded = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      res = await (switch (method) {
        'GET' => http.get(uri, headers: headers),
        'PUT' => http.put(uri, headers: headers, body: encoded),
        'DELETE' => http.delete(uri, headers: headers, body: encoded),
        _ => http.post(uri, headers: headers, body: encoded),
      })
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Le serveur ne répond pas. Réessayez plus tard.');
    } catch (e) {
      debugPrint('ApiService network error: $e');
      throw const ApiException('Connexion au serveur impossible. Vérifiez internet.');
    }

    if (res.statusCode == 401 && auth && !retried && await _refresh()) {
      return _request(method, path, body: body, query: query, auth: auth, retried: true);
    }

    final dynamic data = res.body.isEmpty ? null : _tryDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && auth) await _clearSession();
    throw ApiException(_errorMessage(data, res.statusCode), statusCode: res.statusCode);
  }

  static dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _errorMessage(dynamic data, int status) {
    if (data is Map) {
      final m = data['message'];
      if (m is List && m.isNotEmpty) return m.join('\n');
      if (m is String && m.isNotEmpty) return m;
    }
    if (status == 401) return 'Session expirée, reconnectez-vous';
    if (status >= 500) return 'Erreur serveur ($status)';
    return 'Requête refusée ($status)';
  }

  /// Rafraîchit le jeton d'accès (une seule requête à la fois).
  static Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse('${Env.apiBaseUrl}/auth/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200 && res.statusCode != 201) {
        await _clearSession();
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = data['accessToken'];
      _refreshToken = data['refreshToken'];
      await _saveSession();
      return true;
    } catch (e) {
      debugPrint('ApiService refresh error: $e');
      return false;
    }
  }
}
