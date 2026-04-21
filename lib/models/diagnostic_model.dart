class DiagnosticModel {
  final String objectName;
  final double confidence;
  final String status; // CRITIQUE | ATTENTION | BON ÉTAT
  final String problem;
  final List<String> thinking;
  final List<String> steps;
  final List<String> parts;

  DiagnosticModel({
    required this.objectName,
    required this.confidence,
    required this.status,
    required this.problem,
    required this.thinking,
    required this.steps,
    required this.parts,
  });

  // ── fromJson — pour les réponses réelles de Gemma 4 ──────────────────────
  factory DiagnosticModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticModel(
      objectName: json['objectName'] ?? 'Objet inconnu',
      confidence: (json['confidence'] ?? 0.85).toDouble(),
      status: json['status'] ?? 'ATTENTION',
      problem: json['problem'] ?? 'Analyse en cours...',
      thinking: List<String>.from(json['thinking'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      parts: List<String>.from(json['parts'] ?? []),
    );
  }

  // ── Mock alternateur — démo hackathon ────────────────────────────────────
  factory DiagnosticModel.mock() {
    return DiagnosticModel(
      objectName: 'Alternateur Bosch AL65J',
      confidence: 0.87,
      status: 'CRITIQUE',
      problem:
          'Condensateur principal gonflé détecté. Surchauffe visible estimée à 180°C. '
          'Remplacement immédiat recommandé avant panne totale du système électrique.',
      thinking: [
        "J'observe une déformation anormale sur le condensateur C1...",
        "La coloration bleutée du métal indique une surchauffe à ~180°C...",
        "Le composant présente un risque imminent de court-circuit...",
        "Diagnostic confirmé : remplacement du condensateur C1 nécessaire.",
      ],
      steps: [
        'Couper l\'alimentation électrique et débrancher la batterie',
        'Dévisser le capot protecteur (4 vis cruciformes aux angles)',
        'Localiser le condensateur C1 — cylindre noir près du régulateur',
        'Dessouder les 2 connexions avec fer à souder (350°C max)',
        'Remplacer par condensateur 470µF 25V (même polarité)',
        'Ressouder soigneusement et vérifier les connexions',
        'Rebrancher la batterie et tester le système',
      ],
      parts: [
        'Condensateur 470µF 25V',
        'Régulateur 12V',
        'Pont de Diodes',
      ],
    );
  }

  // ── Mock pompe hydraulique ────────────────────────────────────────────────
  factory DiagnosticModel.mockPump() {
    return DiagnosticModel(
      objectName: 'Pompe Hydraulique X-200',
      confidence: 0.91,
      status: 'ATTENTION',
      problem:
          'Joint d\'étanchéité usé détecté. Fuite hydraulique mineure identifiée '
          'au niveau du raccord principal. Maintenance préventive recommandée.',
      thinking: [
        "J'observe des traces d'huile autour du raccord principal...",
        "L'usure du joint suggère une utilisation de 800h+ sans maintenance...",
        "Pression interne potentiellement réduite de 15%...",
        "Remplacement du joint préventif recommandé sous 48h.",
      ],
      steps: [
        'Dépressuriser le circuit hydraulique complètement',
        'Nettoyer la zone du raccord avec un chiffon sec',
        'Dévisser le raccord principal (clé de 17mm)',
        'Retirer l\'ancien joint torique',
        'Installer le nouveau joint (référence JT-200-17)',
        'Revisser et vérifier l\'étanchéité sous pression',
      ],
      parts: [
        'Joint torique JT-200-17',
        'Raccord hydraulique 17mm',
      ],
    );
  }
}