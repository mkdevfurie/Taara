import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taara/models/diagnostic_model.dart';

/// Service de persistance de l'historique des diagnostics
class HistoryService {
  static const String _key = 'taara_history';
  static const int _maxEntries = 50;

  /// Charger tout l'historique depuis le stockage local
  static Future<List<DiagnosticModel>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => DiagnosticModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('HistoryService.load error: $e');
      return [];
    }
  }

  /// Ajouter un diagnostic en tête de liste
  static Future<void> add(DiagnosticModel diagnostic) async {
    if (diagnostic.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await load();
      current.insert(0, diagnostic);
      // Limiter à _maxEntries entrées
      final trimmed = current.take(_maxEntries).toList();
      await prefs.setString(
        _key,
        jsonEncode(trimmed.map((d) => d.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('HistoryService.add error: $e');
    }
  }

  /// Supprimer un diagnostic par index
  static Future<void> remove(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await load();
      if (index >= 0 && index < current.length) {
        current.removeAt(index);
        await prefs.setString(
          _key,
          jsonEncode(current.map((d) => d.toMap()).toList()),
        );
      }
    } catch (e) {
      debugPrint('HistoryService.remove error: $e');
    }
  }

  /// Effacer tout l'historique
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('HistoryService.clear error: $e');
    }
  }

  /// Statistiques
  static Future<Map<String, int>> stats() async {
    final history = await load();
    return {
      'total': history.length,
      'critique': history.where((d) => d.status == 'CRITIQUE').length,
      'attention': history.where((d) => d.status == 'ATTENTION').length,
      'bonEtat': history.where((d) => d.status == 'BON ÉTAT').length,
    };
  }
}