import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EwastePredictionResult {
  const EwastePredictionResult({
    required this.label,
    required this.confidence,
    required this.classIndex,
    required this.probabilities,
  });

  final String label;
  final double confidence;
  final int classIndex;
  final List<double> probabilities;

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  String get displayLabel {
    switch (label) {
      case 'pcb':
        return 'PCB / Printed Circuit Board';
      case 'battery':
        return 'Battery';
      case 'phone':
        return 'Mobile Phone';
      default:
        return label;
    }
  }
}

class EwasteClassifierService {
  EwasteClassifierService._();
  static final EwasteClassifierService instance = EwasteClassifierService._();

  Interpreter? _interpreter;
  bool _isInitializing = false;

  static const String modelAssetPath = 'assets/tflite/ewaste_classifier.tflite';
  static const int inputWidth = 224;
  static const int inputHeight = 224;
  static const List<String> labels = ['pcb', 'battery', 'phone'];

  Future<void> initialize() async {
    if (_interpreter != null) return;
    if (_isInitializing) return;

    _isInitializing = true;
    try {
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);
      if (kDebugMode) {
        print('TFLite Model loaded successfully from $modelAssetPath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading TFLite model: $e');
      }
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<EwastePredictionResult?> classifyImage(String photoPath) async {
    try {
      await initialize();
      if (_interpreter == null) return null;

      final file = File(photoPath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      // Resize to 224x224 RGB
      final resizedImage = img.copyResize(
        decodedImage,
        width: inputWidth,
        height: inputHeight,
      );

      // Preprocess image into shape [1, 224, 224, 3] with pixel / 255.0 normalization
      final input = List.generate(
        1,
        (_) => List.generate(
          inputHeight,
          (y) => List.generate(
            inputWidth,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Output shape is [1, 3]
      final output = List.generate(1, (_) => List<double>.filled(labels.length, 0.0));

      // Run offline inference
      _interpreter!.run(input, output);

      final rawProbabilities = output[0];
      int maxIndex = 0;
      double maxProb = rawProbabilities[0];

      for (int i = 1; i < rawProbabilities.length; i++) {
        if (rawProbabilities[i] > maxProb) {
          maxProb = rawProbabilities[i];
          maxIndex = i;
        }
      }

      final predictedLabel = labels[maxIndex];

      return EwastePredictionResult(
        label: predictedLabel,
        confidence: maxProb,
        classIndex: maxIndex,
        probabilities: rawProbabilities,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error classifying e-waste image: $e');
      }
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
