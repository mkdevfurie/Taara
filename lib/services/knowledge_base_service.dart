import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:taara/models/diagnostic_model.dart';

/// Service de recherche dans la base de connaissances locale embarquée.
/// Fonctionne 100% hors-ligne — aucune connexion requise.
class KnowledgeBaseService {
  static List<Map<String, dynamic>>? _cache;

  /// Charge la base de connaissances depuis les assets Flutter
  static Future<List<Map<String, dynamic>>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/knowledge_base.json');
    _cache = List<Map<String, dynamic>>.from(jsonDecode(raw));
    return _cache!;
  }

  /// Recherche les entrées les plus pertinentes pour une description donnée.
  /// Retourne null si aucune entrée ne dépasse le seuil de pertinence.
  static Future<DiagnosticModel?> search(String description) async {
    if (description.trim().isEmpty) return null;

    final entries = await _load();
    final query = description.toLowerCase();
    final queryWords = query
        .split(RegExp(r'[\s,;.!?]+'))
        .where((w) => w.length > 2)
        .toList();

    int bestScore = 0;
    Map<String, dynamic>? bestEntry;

    for (final entry in entries) {
      final keywords = List<String>.from(entry['keywords'] ?? []);
      int score = 0;

      for (final keyword in keywords) {
        final kw = keyword.toLowerCase();
        // Score +3 si le mot-clé apparaît tel quel dans la description
        if (query.contains(kw)) {
          score += 3;
        } else {
          // Score +1 si un mot de la description commence par ce mot-clé
          for (final word in queryWords) {
            if (word.startsWith(kw) || kw.startsWith(word)) {
              score += 1;
              break;
            }
          }
        }
      }

      // Bonus si le nom de l'objet apparaît directement dans la description
      final objName = (entry['objectName'] as String).toLowerCase();
      if (query.contains(objName)) score += 5;

      if (score > bestScore) {
        bestScore = score;
        bestEntry = entry;
      }
    }

    // Seuil minimum : au moins 2 points de pertinence
    if (bestScore < 2 || bestEntry == null) return null;

    return DiagnosticModel(
      objectName: bestEntry['objectName'] as String,
      confidence: (bestEntry['confidence'] as num).toDouble(),
      status: bestEntry['status'] as String,
      problem: bestEntry['problem'] as String,
      thinking: List<String>.from(bestEntry['thinking'] ?? []),
      steps: List<String>.from(bestEntry['steps'] ?? []),
      parts: List<String>.from(bestEntry['parts'] ?? []),
      searchTerms: List<String>.from(bestEntry['searchTerms'] ?? []),
      analyzedAt: DateTime.now(),
    );
  }

  /// Recherche par catégorie (moteur, pompe, medical, etc.)
  static Future<List<DiagnosticModel>> getByCategory(String category) async {
    final entries = await _load();
    return entries
        .where((e) =>
            (e['category'] as String).toLowerCase() ==
            category.toLowerCase())
        .map((e) => DiagnosticModel(
              objectName: e['objectName'] as String,
              confidence: (e['confidence'] as num).toDouble(),
              status: e['status'] as String,
              problem: e['problem'] as String,
              thinking: List<String>.from(e['thinking'] ?? []),
              steps: List<String>.from(e['steps'] ?? []),
              parts: List<String>.from(e['parts'] ?? []),
              searchTerms: List<String>.from(e['searchTerms'] ?? []),
              analyzedAt: DateTime.now(),
            ))
        .toList();
  }

  /// Retourne toutes les catégories disponibles avec leur nombre d'entrées
  static Future<Map<String, int>> getCategories() async {
    final entries = await _load();
    final Map<String, int> cats = {};
    for (final e in entries) {
      final cat = e['category'] as String;
      cats[cat] = (cats[cat] ?? 0) + 1;
    }
    return cats;
  }

  /// Nombre total d'entrées dans la base
  static Future<int> count() async {
    final entries = await _load();
    return entries.length;
  }
}