import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/config/env.dart';
import 'package:taara/services/knowledge_base_service.dart';

class GemmaService {
  static const String _apiKey = Env.geminiApiKey;
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:generateContent';

  // ── Clé de cache SharedPreferences ────────────────────────────────────────
  static const String _cacheKey = 'taara_offline_cache';
  static const int _maxCacheEntries = 20;

  static bool get hasApiKey => _apiKey.isNotEmpty;

  // ── Vérifie si l'appareil a accès à internet ──────────────────────────────
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('generativelanguage.googleapis.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Analyse d'image : online → cache → offline ───────────────────────────
  static Future<DiagnosticResult> analyzeImage(File imageFile) async {
    if (!hasApiKey) {
      debugPrint('GemmaService: Aucune clé API — mode dégradé');
      return DiagnosticResult(
        model: DiagnosticModel.empty(),
        source: DiagnosticSource.error,
      );
    }

    final online = await isOnline();

    if (online) {
      // Mode online : appel API réel
      try {
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final ext = imageFile.path.toLowerCase().split('.').last;
        final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

        const prompt = '''
Tu es Taara, un expert en diagnostic technique de machines et équipements.
Analyse cette image et réponds UNIQUEMENT en JSON valide avec cette structure exacte :

{
  "objectName": "nom exact de l'objet identifié",
  "confidence": 0.87,
  "status": "CRITIQUE",
  "problem": "description claire du problème détecté",
  "thinking": [
    "première observation technique",
    "deuxième observation",
    "conclusion du diagnostic"
  ],
  "steps": [
    "étape 1 de réparation",
    "étape 2",
    "étape 3"
  ],
  "parts": [
    "pièce nécessaire 1",
    "pièce nécessaire 2"
  ],
  "searchTerms": [
    "terme de recherche court pour commander la pièce 1",
    "terme de recherche court pour commander la pièce 2"
  ]
}

Règles strictes :
- status doit être exactement : CRITIQUE, ATTENTION, ou BON ÉTAT
- confidence entre 0.0 et 1.0
- thinking : raisonnement visible étape par étape
- steps : guide de réparation concret et actionnable
- parts : pièces de rechange nécessaires
- searchTerms : un terme de recherche court et précis par pièce (ex: "condensateur 16V 1000uF")
- Réponds UNIQUEMENT avec le JSON, sans texte avant ou après
- Si tu ne reconnais pas l'objet, indique "Objet non identifié" dans objectName
''';

        final response = await http
            .post(
              Uri.parse('$_baseUrl?key=$_apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Image,
                        }
                      },
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.2,
                  'maxOutputTokens': 1024,
                },
                'safetySettings': [
                  {
                    'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                    'threshold': 'BLOCK_NONE'
                  }
                ]
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final parts = data['candidates'][0]['content']['parts'] as List;
          final textPart = parts.lastWhere(
            (p) => p['thought'] != true,
            orElse: () => parts.last,
          );
          final text = textPart['text'] as String;
          debugPrint('Gemma 4 response: $text');

          final cleanJson = text
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          final parsed = jsonDecode(cleanJson);
          final model = DiagnosticModel.fromJson(parsed);

          // Mettre en cache pour usage offline
          await _cacheResult(model);

          return DiagnosticResult(model: model, source: DiagnosticSource.online);
        } else {
          debugPrint('API Error ${response.statusCode}: ${response.body}');
          // Tentative de fallback sur le cache
          return await _fallbackToCache(description: description);
        }
      } on SocketException {
        debugPrint('GemmaService: Connexion perdue — fallback cache');
        return await _fallbackToCache(description: '');
      } catch (e) {
        debugPrint('GemmaService error: $e');
        return await _fallbackToCache(description: '');
      }
    } else {
      // Mode offline : réponse depuis le cache
      debugPrint('GemmaService: Pas de connexion — mode offline');
      return await _fallbackToCache(description: '');
    }
  }

  // ── Analyse vocale/texte : online → cache → offline ──────────────────────
  static Future<DiagnosticResult> analyzeText({
    required String description,
    File? image,
  }) async {
    if (!hasApiKey) {
      return DiagnosticResult(
        model: DiagnosticModel.empty(),
        source: DiagnosticSource.error,
      );
    }

    final online = await isOnline();

    if (online) {
      try {
        final prompt = '''
Tu es Taara, expert en diagnostic technique de machines et équipements.
Un utilisateur décrit oralement un problème avec un équipement.

Description : "$description"

Réponds UNIQUEMENT en JSON valide avec cette structure :
{
  "objectName": "nom exact de l'équipement décrit",
  "confidence": 0.80,
  "status": "ATTENTION",
  "problem": "synthèse claire du problème détecté",
  "thinking": [
    "première observation basée sur la description",
    "deuxième observation technique",
    "conclusion du diagnostic"
  ],
  "steps": [
    "étape 1 de réparation concrète",
    "étape 2",
    "étape 3"
  ],
  "parts": ["pièce nécessaire 1", "pièce nécessaire 2"],
  "searchTerms": ["terme de recherche court pièce 1", "terme de recherche court pièce 2"]
}
status = CRITIQUE | ATTENTION | BON ÉTAT. JSON uniquement, sans texte autour.
''';

        final List<Map<String, dynamic>> parts = [
          {'text': prompt}
        ];

        if (image != null) {
          final bytes = await image.readAsBytes();
          final b64 = base64Encode(bytes);
          final ext = image.path.toLowerCase().split('.').last;
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          parts.insert(0, {
            'inline_data': {'mime_type': mime, 'data': b64}
          });
        }

        final response = await http
            .post(
              Uri.parse('$_baseUrl?key=$_apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {
                  'temperature': 0.2,
                  'maxOutputTokens': 1024,
                },
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final partsList = data['candidates'][0]['content']['parts'] as List;
          final textPart = partsList.lastWhere(
            (p) => p['thought'] != true,
            orElse: () => partsList.last,
          );
          final text = (textPart['text'] as String)
              .replaceAll('```json', '')
              .replaceAll('```', '')
              .trim();

          final model = DiagnosticModel.fromJson(jsonDecode(text));
          await _cacheResult(model);
          return DiagnosticResult(model: model, source: DiagnosticSource.online);
        }

        return await _fallbackToCache(description: '');
      } catch (e) {
        debugPrint('GemmaService.analyzeText error: $e');
        return await _fallbackToCache(description: '');
      }
    } else {
      return await _fallbackToCache(description: '');
    }
  }

  // ── Cache offline ─────────────────────────────────────────────────────────

  /// Sauvegarde un résultat dans le cache offline
  static Future<void> _cacheResult(DiagnosticModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final List<dynamic> cache = raw != null ? jsonDecode(raw) : [];

      // Ajoute en tête, déduplique par objectName
      cache.removeWhere((e) => e['objectName'] == model.objectName);
      cache.insert(0, model.toMap());

      // Limite la taille du cache
      final trimmed = cache.take(_maxCacheEntries).toList();
      await prefs.setString(_cacheKey, jsonEncode(trimmed));
      debugPrint('GemmaService: résultat mis en cache (${trimmed.length} entrées)');
    } catch (e) {
      debugPrint('GemmaService._cacheResult error: $e');
    }
  }

  /// Retourne le diagnostic le plus pertinent depuis le cache offline,
  /// puis la base de connaissances locale, puis un message d\'erreur.
  static Future<DiagnosticResult> _fallbackToCache({String description = ''}) async {
    // 1. Essai depuis le cache SharedPreferences (diagnostics déjà effectués)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final List<dynamic> cache = jsonDecode(raw);
        if (cache.isNotEmpty) {
          final model = DiagnosticModel.fromMap(
            Map<String, dynamic>.from(cache.first),
          );
          debugPrint('GemmaService: résultat depuis cache SharedPreferences');
          return DiagnosticResult(model: model, source: DiagnosticSource.offline);
        }
      }
    } catch (e) {
      debugPrint('GemmaService._fallbackToCache cache error: $e');
    }

    // 2. Recherche dans la base de connaissances embarquée (offline dès le 1er lancement)
    if (description.trim().isNotEmpty) {
      try {
        final kbResult = await KnowledgeBaseService.search(description);
        if (kbResult != null) {
          debugPrint('GemmaService: résultat depuis base de connaissances locale');
          return DiagnosticResult(model: kbResult, source: DiagnosticSource.knowledgeBase);
        }
      } catch (e) {
        debugPrint('GemmaService._fallbackToCache KB error: $e');
      }
    }

    // 3. Aucune source disponible
    return DiagnosticResult(
      model: _offlineEmptyModel(),
      source: DiagnosticSource.offlineEmpty,
    );
  }

  /// Charge tous les diagnostics en cache (pour affichage dans l'UI offline)
  static Future<List<DiagnosticModel>> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      final List<dynamic> cache = jsonDecode(raw);
      return cache
          .map((e) => DiagnosticModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static DiagnosticModel _offlineEmptyModel() {
    return DiagnosticModel(
      objectName: 'Mode hors-ligne',
      confidence: 0.0,
      status: 'ATTENTION',
      problem:
          'Aucune connexion internet détectée. Utilisez Taara en ligne pour obtenir un diagnostic complet.\n\n'
          'Conseil : effectuez quelques diagnostics en ligne pour alimenter le cache local.',
      thinking: [
        'Connexion API indisponible — Gemma 4 nécessite internet pour ce modèle',
        'Aucun diagnostic similaire trouvé dans le cache local',
        'Recommandation : connectez-vous et relancez l\'analyse',
      ],
      steps: [
        'Vérifiez votre connexion WiFi ou données mobiles',
        'Relancez Taara une fois connecté',
        'Vos prochains diagnostics seront mis en cache pour usage offline',
      ],
      parts: [],
      searchTerms: [],
      analyzedAt: DateTime.now(),
    );
  }
}

// ── Modèles de résultat ────────────────────────────────────────────────────────

enum DiagnosticSource {
  online,    // Réponse fraîche de Gemma 4
  offline,   // Depuis le cache local
  offlineEmpty, // Offline ET cache vide
  knowledgeBase, // Depuis la base de connaissances embarquée
  error,     // Erreur de config (pas de clé API)
}

class DiagnosticResult {
  final DiagnosticModel model;
  final DiagnosticSource source;

  const DiagnosticResult({required this.model, required this.source});

  bool get isOnline => source == DiagnosticSource.online;
  bool get isOffline => source == DiagnosticSource.offline || source == DiagnosticSource.offlineEmpty || source == DiagnosticSource.knowledgeBase;
  bool get isCached => source == DiagnosticSource.offline || source == DiagnosticSource.knowledgeBase;

  String get sourceBadge {
    switch (source) {
      case DiagnosticSource.online:
        return 'Gemma 4 • En ligne';
      case DiagnosticSource.offline:
        return 'Cache local • Hors-ligne';
      case DiagnosticSource.offlineEmpty:
        return 'Hors-ligne • Aucun cache';
      case DiagnosticSource.knowledgeBase:
        return 'Base locale • Hors-ligne';
      case DiagnosticSource.error:
        return 'Erreur de config';
    }
  }
}