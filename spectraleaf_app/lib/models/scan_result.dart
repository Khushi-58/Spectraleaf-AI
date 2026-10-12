/// Model for a single deficiency scan result
class ScanResult {
  final String deficiencyClass;
  final double confidence;
  final double spadValue;
  final String spadStatus;
  final Map<String, double> allProbabilities;
  final String mode; // 'standard' or 'spectrometer'
  final DateTime timestamp;

  const ScanResult({
    required this.deficiencyClass,
    required this.confidence,
    required this.spadValue,
    required this.spadStatus,
    required this.allProbabilities,
    required this.mode,
    required this.timestamp,
  });

  /// Human-readable deficiency name with emoji
  String get displayName {
    const labels = {
      'healthy':   '✅ Healthy',
      'nitrogen':  '🟡 Nitrogen Deficiency',
      'iron':      '🔴 Iron Deficiency',
      'magnesium': '🟠 Magnesium Deficiency',
      'potassium': '🟣 Potassium Deficiency',
    };
    return labels[deficiencyClass] ?? deficiencyClass;
  }

  /// Color for the deficiency indicator
  int get indicatorColor {
    if (deficiencyClass == 'healthy') return 0xFF10B981; // Emerald
    if (confidence > 80) return 0xFFEF4444;              // Red
    return 0xFFF59E0B;                                    // Amber
  }

  /// Fertilizer recommendation
  String get recommendation {
    const recs = {
      'healthy':   'No treatment needed. Maintain current nutrient schedule.',
      'nitrogen':  'Apply Urea (46-0-0) at 40-60 kg/ha, or liquid nitrogen fertigation.',
      'iron':      'Foliar spray with Fe-EDTA Chelates (1-2 g/L). Adjust soil pH if alkaline.',
      'magnesium': 'Apply Magnesium Sulfate (Epsom Salt) at 10-20 g/L as foliar spray.',
      'potassium': 'Incorporate Potassium Sulfate (SOP) at 40-50 kg/ha before planting.',
    };
    return recs[deficiencyClass] ?? 'Consult an agronomist for specific guidance.';
  }

  /// SPAD status text
  static String getSpadStatus(double spad) {
    if (spad >= 50) return 'Optimal';
    if (spad >= 40) return 'Adequate';
    if (spad >= 30) return 'Low Chlorophyll';
    return 'Critical';
  }

  Map<String, dynamic> toJson() => {
    'deficiencyClass': deficiencyClass,
    'confidence': confidence,
    'spadValue': spadValue,
    'spadStatus': spadStatus,
    'allProbabilities': allProbabilities,
    'mode': mode,
    'timestamp': timestamp.toIso8601String(),
  };
}
