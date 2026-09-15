import 'package:flutter_test/flutter_test.dart';
import 'package:kabadi_connect/ewaste_classifier_service.dart';

void main() {
  test('EwastePredictionResult formats labels and confidence correctly', () {
    const pcbResult = EwastePredictionResult(
      label: 'pcb',
      confidence: 0.9452,
      classIndex: 0,
      probabilities: [0.9452, 0.03, 0.0248],
    );

    expect(pcbResult.label, equals('pcb'));
    expect(pcbResult.confidencePercentage, equals('94.5%'));
    expect(pcbResult.displayLabel, equals('PCB / Printed Circuit Board'));

    const batteryResult = EwastePredictionResult(
      label: 'battery',
      confidence: 0.881,
      classIndex: 1,
      probabilities: [0.05, 0.881, 0.069],
    );

    expect(batteryResult.label, equals('battery'));
    expect(batteryResult.confidencePercentage, equals('88.1%'));
    expect(batteryResult.displayLabel, equals('Battery'));

    const phoneResult = EwastePredictionResult(
      label: 'phone',
      confidence: 0.99,
      classIndex: 2,
      probabilities: [0.005, 0.005, 0.99],
    );

    expect(phoneResult.label, equals('phone'));
    expect(phoneResult.confidencePercentage, equals('99.0%'));
    expect(phoneResult.displayLabel, equals('Mobile Phone'));
  });
}
