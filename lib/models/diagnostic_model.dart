class DiagnosticModel {
  final String objectName;
  final double confidence;
  final String status; // CRITIQUE | ATTENTION | BON ÉTAT
  final String problem;
  final List<String> thinking;
  final List<String> steps;
  final List<String> parts;
  final List<String> searchTerms; // Termes de recherche pour commander les pièces
  final DateTime? analyzedAt;

  DiagnosticModel({
    required this.objectName,
    required this.confidence,
    required this.status,
    required this.problem,
    required this.thinking,
    required this.steps,
    required this.parts,
    this.searchTerms = const [],
    this.analyzedAt,
  });

  // ── fromJson — pour les réponses réelles de Gemma 4 ──────────────────────
  factory DiagnosticModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticModel(
      objectName: json['objectName'] ?? 'Objet inconnu',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'ATTENTION',
      problem: json['problem'] ?? 'Analyse indisponible.',
      thinking: List<String>.from(json['thinking'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      parts: List<String>.from(json['parts'] ?? []),
      searchTerms: List<String>.from(json['searchTerms'] ?? []),
      analyzedAt: DateTime.now(),
    );
  }

  // ── fromMap — pour la persistance locale (SharedPreferences) ─────────────
  factory DiagnosticModel.fromMap(Map<String, dynamic> map) {
    return DiagnosticModel(
      objectName: map['objectName'] ?? '',
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'ATTENTION',
      problem: map['problem'] ?? '',
      thinking: List<String>.from(map['thinking'] ?? []),
      steps: List<String>.from(map['steps'] ?? []),
      parts: List<String>.from(map['parts'] ?? []),
      searchTerms: List<String>.from(map['searchTerms'] ?? []),
      analyzedAt: map['analyzedAt'] != null
          ? DateTime.tryParse(map['analyzedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'objectName': objectName,
      'confidence': confidence,
      'status': status,
      'problem': problem,
      'thinking': thinking,
      'steps': steps,
      'parts': parts,
      'searchTerms': searchTerms,
      'analyzedAt': (analyzedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  // ── Résultat vide — quand l'API est indisponible ──────────────────────────
  factory DiagnosticModel.empty() {
    return DiagnosticModel(
      objectName: 'Analyse impossible',
      confidence: 0.0,
      status: 'ATTENTION',
      problem:
          'Impossible d\'analyser l\'image. Vérifiez votre connexion internet et que la clé API est correctement configurée.',
      thinking: [],
      steps: [],
      parts: [],
      searchTerms: [],
      analyzedAt: DateTime.now(),
    );
  }

  bool get isEmpty => objectName == 'Analyse impossible';
}