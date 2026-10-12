import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/scan_result.dart';

/// Handles TFLite model loading and inference for both Standard (M2) and
/// Spectrometer (Multitask) modes.
class InferenceService {
  static const List<String> _classes = [
    'nitrogen',
    'iron',
    'magnesium',
    'potassium',
    'healthy'
  ];

  // ImageNet normalization constants (same as training pipeline)
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  Interpreter? _m2Interpreter;
  Interpreter? _multitaskInterpreter;

  bool get isM2Loaded => _m2Interpreter != null;
  bool get isMultitaskLoaded => _multitaskInterpreter != null;

  /// Load the Standard (RGB-only) M2 model from app assets
  Future<void> loadM2() async {
    _m2Interpreter?.close();
    _m2Interpreter = await Interpreter.fromAsset(
      'assets/models/model_m2_float16.tflite',
      options: InterpreterOptions()..threads = 4,
    );
    print('[InferenceService] M2 Float16 model loaded.');
  }

  /// Load the Multitask (RGB + Spectral) model from app assets
  Future<void> loadMultitask() async {
    _multitaskInterpreter?.close();
    _multitaskInterpreter = await Interpreter.fromAsset(
      'assets/models/model_multitask_float16.tflite',
      options: InterpreterOptions()..threads = 4,
    );
    print('[InferenceService] Multitask Float16 model loaded.');
  }

  /// Preprocess an image to a normalized Float32 tensor shape (1, 224, 224, 3) NHWC
  Float32List _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: 224, height: 224);
    final buffer = Float32List(1 * 224 * 224 * 3);
    int idx = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[idx++] = (pixel.r / 255.0 - _mean[0]) / _std[0];
        buffer[idx++] = (pixel.g / 255.0 - _mean[1]) / _std[1];
        buffer[idx++] = (pixel.b / 255.0 - _mean[2]) / _std[2];
      }
    }
    return buffer;
  }

  /// Apply sigmoid activation element-wise
  List<double> _sigmoid(List<double> logits) {
    return logits.map((l) => 1.0 / (1.0 + math.exp(-l))).toList();
  }

  /// Run Standard Mode inference using the M2 RGB-only model
  Future<ScanResult> runStandardInference(img.Image image) async {
    if (_m2Interpreter == null) await loadM2();

    final inputBuffer = _preprocessImage(image);
    final input = inputBuffer.reshape([1, 224, 224, 3]);
    final output = {
      0: List<List<double>>.generate(1, (_) => List<double>.filled(5, 0.0))
    };

    _m2Interpreter!.runForMultipleInputs([input], output);

    final probs = _sigmoid(output[0]![0]);
    return _buildResult(probs, 'standard');
  }

  /// Run Spectrometer Mode inference using the Multitask model (RGB + Spectral)
  Future<ScanResult> runSpectrometerInference(
    img.Image image,
    List<double> spectralVector,
  ) async {
    if (_multitaskInterpreter == null) await loadMultitask();

    final imgBuffer = _preprocessImage(image).reshape([1, 224, 224, 3]);
    final specBuffer = Float32List.fromList(spectralVector).reshape([1, 672]);

    // Output index 0: Identity (Logits, shape [1, 5])
    // Output index 1: Identity_1 (SPAD, shape [1, 1])
    final outputs = {
      0: List<List<double>>.generate(1, (_) => List<double>.filled(5, 0.0)),
      1: List<List<double>>.generate(1, (_) => List<double>.filled(1, 0.0)),
    };

    _multitaskInterpreter!
        .runForMultipleInputs([imgBuffer, specBuffer], outputs);

    final probs = _sigmoid(outputs[0]![0]); // Logits output is index 0
    final spad = outputs[1]![0][0].clamp(0.0, 100.0); // SPAD output is index 1
    return _buildResult(probs, 'spectrometer', overrideSpad: spad);
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

    // Use regression head SPAD if available; else estimate from healthy probability
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

  /// Heuristic SPAD proxy for Standard (RGB-only) mode
  /// Maps healthy-class probability → approximate SPAD index [15, 65]
  double _estimateSpad(List<double> probs) {
    final healthyProb = probs[4].clamp(0.0, 1.0); // healthy = index 4
    return 15.0 + healthyProb * 50.0;
  }

  /// Validates if the image is a valid crop leaf image using color saturation, hue ranges,
  /// vegetation indices (GLI, ExG), and unique color count to filter out digital graphics/logos.
  String validateLeafImage(img.Image image) {
    final totalPixels = image.width * image.height;
    if (totalPixels == 0) return 'Invalid empty image.';

    double sumR = 0.0;
    double sumG = 0.0;
    double sumB = 0.0;
    
    double sumGli = 0.0;
    double sumExg = 0.0;
    int leafPixelsCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final double r = pixel.r / 255.0;
        final double g = pixel.g / 255.0;
        final double b = pixel.b / 255.0;

        sumR += r;
        sumG += g;
        sumB += b;

        // Vegetation indices
        final double gliDenom = 2.0 * g + r + b;
        final double gli = gliDenom != 0.0 ? (2.0 * g - r - b) / gliDenom : 0.0;
        final double exg = (2.0 * g - r - b + 1.0) / 3.0;

        sumGli += gli;
        sumExg += exg;

        // Convert RGB to HSV for leaf color check
        // Hue range [0..360], Saturation [0..1], Value [0..1]
        final double max = math.max(r, math.max(g, b));
        final double min = math.min(r, math.min(g, b));
        final double d = max - min;
        double h = 0.0;
        final double s = max == 0.0 ? 0.0 : d / max;
        final double v = max;

        if (max != min) {
          if (max == r) {
            h = (g - b) / d + (g < b ? 6.0 : 0.0);
          } else if (max == g) {
            h = (b - r) / d + 2.0;
          } else if (max == b) {
            h = (r - g) / d + 4.0;
          }
          h /= 6.0;
        }
        final double hDeg = h * 360.0;

        // Hue range: [0, 170] or [330, 360] degrees
        final bool hueMask = (hDeg >= 0 && hDeg <= 170) || (hDeg >= 330 && hDeg <= 360);
        final bool satMask = s > 0.137; // s > 35/255
        final bool valMask = v > 0.117; // v > 30/255

        if (hueMask && satMask && valMask) {
          leafPixelsCount++;
        }
      }
    }

    final double avgIntensity = (sumR + sumG + sumB) / (totalPixels * 3.0);
    final double avgGli = sumGli / totalPixels;
    final double avgExg = sumExg / totalPixels;
    final double leafRatio = leafPixelsCount / totalPixels;

    // Unique colors check (resize image to 128x128 to keep it super fast)
    final small = img.copyResize(image, width: 128, height: 128);
    final colorsSet = <int>{};
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final rgb = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
        colorsSet.add(rgb);
      }
    }
    
    final int uniqueColors = colorsSet.length;

    if (avgIntensity < 0.06) {
      return 'The uploaded image is too dark. Please ensure adequate lighting and center the leaf.';
    }
    if (uniqueColors < 1000) {
      return 'The uploaded image appears to be a digital graphic, logo, or flat color block rather than a real plant leaf photo.';
    }
    if (leafRatio < 0.25 || avgExg < 0.33 || avgGli < -0.02) {
      return 'The uploaded image does not appear to contain a valid crop leaf. Please verify that you are scanning a plant leaf.';
    }

    return ''; // Valid
  }

  void dispose() {
    _m2Interpreter?.close();
    _multitaskInterpreter?.close();
  }
}
