import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:taara/models/diagnostic_model.dart';
import 'package:taara/config/env.dart';

class GemmaService {
  static const String _apiKey = Env.geminiApiKey;

  // Gemma 4 multimodal
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:generateContent';

  static bool get hasApiKey => _apiKey.isNotEmpty;

  static Future<DiagnosticModel> analyzeImage(File imageFile) async {
    // Si pas de clé API configurée, retourner un diagnostic vide
    if (!hasApiKey) {
      debugPrint('GemmaService: Aucune clé API — mode dégradé');
      return DiagnosticModel.empty();
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Détection du type MIME réel selon l'extension
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
  ]
}

Règles strictes :
- status doit être exactement : CRITIQUE, ATTENTION, ou BON ÉTAT
- confidence entre 0.0 et 1.0
- thinking : raisonnement visible étape par étape
- steps : guide de réparation concret et actionnable
- parts : pièces de rechange nécessaires
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

        // Gemma 4 retourne 2 parts :
        // part[0] = "thought" (raisonnement interne, thought: true)
        // part[1] = vrai texte final
        final parts = data['candidates'][0]['content']['parts'] as List;
        final textPart = parts.lastWhere(
          (p) => p['thought'] != true,
          orElse: () => parts.last,
        );
        final text = textPart['text'] as String;

        debugPrint('Gemma 4 response: $text');

        // Nettoyer le JSON — enlever backticks et espaces
        final cleanJson = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = jsonDecode(cleanJson);
        return DiagnosticModel.fromJson(parsed);
      } else {
        debugPrint('API Error ${response.statusCode}: ${response.body}');
        return DiagnosticModel.empty();
      }
    } on SocketException {
      debugPrint('GemmaService: Pas de connexion — mode offline');
      return DiagnosticModel.empty();
    } catch (e) {
      debugPrint('GemmaService error: $e');
      return DiagnosticModel.empty();
    }
  }
}