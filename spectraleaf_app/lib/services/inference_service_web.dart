import 'package:image/image.dart' as img;
import '../models/scan_result.dart';

class InferenceService {
  static const List<String> _classes = [
    'nitrogen',
    'iron',
    'magnesium',
    'potassium',
    'healthy',
  ];

  bool get isM2Loaded => true;
  bool get isMultitaskLoaded => true;

  Future<void> loadM2() async {}

  Future<void> loadMultitask() async {}

  Future<ScanResult> runStandardInference(img.Image image) async {
    // Web placeholder inference.
    // The Android version continues using the actual TFLite model.

    final result = _webPrediction(image);

    return _buildResult(
      result,
      'standard',
    );
  }

  Future<ScanResult> runSpectrometerInference(
    img.Image image,
    List<double> spectralVector,
  ) async {
    // Web placeholder inference.
    // Android continues using the actual multitask TFLite model.

    final result = _webPrediction(image);

    return _buildResult(
      result,
      'spectrometer',
      overrideSpad: 40.0,
    );
  }

  List<double> _webPrediction(img.Image image) {
    double r = 0;
    double g = 0;
    double b = 0;

    final total = image.width * image.height;

    if (total == 0) {
      return [0.2, 0.2, 0.2, 0.2, 0.2];
    }

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        r += pixel.r / 255.0;
        g += pixel.g / 255.0;
        b += pixel.b / 255.0;
      }
    }

    r /= total;
    g /= total;
    b /= total;

    final greenScore = g - ((r + b) / 2);

    double nitrogen = 0.2;
    double iron = 0.2;
    double magnesium = 0.2;
    double potassium = 0.2;
    double healthy = 0.2;

    if (greenScore > 0.15) {
      healthy = 0.70;
      nitrogen = 0.08;
      iron = 0.07;
      magnesium = 0.08;
      potassium = 0.07;
    } else if (r > g) {
      iron = 0.45;
      healthy = 0.20;
      nitrogen = 0.15;
      magnesium = 0.10;
      potassium = 0.10;
    } else {
      nitrogen = 0.30;
      magnesium = 0.25;
      potassium = 0.20;
      iron = 0.10;
      healthy = 0.15;
    }

    return [
      nitrogen,
      iron,
      magnesium,
      potassium,
      healthy,
    ];
  }

  ScanResult _buildResult(
    List<double> probs,
    String mode, {
    double? overrideSpad,
  }) {
    final Map<String, double> allProbs = {};

    for (int i = 0; i < _classes.length; i++) {
      allProbs[_classes[i]] = probs[i] * 100.0;
    }

    final primary = allProbs.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final spad = overrideSpad ?? _estimateSpad(probs);

    return ScanResult(
      deficiencyClass: primary.key,
      confidence: primary.value,
      spadValue: spad,
      spadStatus: ScanResult.getSpadStatus(spad),
      allProbabilities: allProbs,
      mode: mode,
      timestamp: DateTime.now(),
    );
  }

  double _estimateSpad(List<double> probs) {
    final healthyProb = probs[4].clamp(0.0, 1.0);

    return 15.0 + healthyProb * 50.0;
  }

  String validateLeafImage(img.Image image) {
    final totalPixels = image.width * image.height;

    if (totalPixels == 0) {
      return 'Invalid empty image.';
    }

    double sumR = 0.0;
    double sumG = 0.0;
    double sumB = 0.0;

    int greenPixels = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        sumR += r;
        sumG += g;
        sumB += b;

        if (g > r * 0.8 && g > b * 0.8) {
          greenPixels++;
        }
      }
    }

    final avgIntensity =
        (sumR + sumG + sumB) / (totalPixels * 3.0);

    final greenRatio = greenPixels / totalPixels;

    if (avgIntensity < 0.06) {
      return 'The uploaded image is too dark. Please ensure adequate lighting and center the leaf.';
    }

    if (greenRatio < 0.10) {
      return 'The uploaded image does not appear to contain a valid crop leaf. Please verify that you are scanning a plant leaf.';
    }

    return '';
  }

  void dispose() {}
}