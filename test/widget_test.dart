// Replacement for the obsolete starter widget test.
// Pure input-validation tests only: no Firebase writes, SMS or TTS calls.
// These do not substitute for device, Auth or Firestore rules tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabadi_connect/quick_profile_service.dart';
import 'package:kabadi_connect/collector_store.dart';

void main() {
  test('weight range includes positive fractions and max 10000 kg', () {
    for (final w in [0.01, 1, 2.5, 10000]) {
      expect(CollectorStore.validWeight(w), isTrue);
    }
  });
  test(
    'weight rejects zero, negatives, infinity, NaN and excessive values',
    () {
      for (final w in [0, -1, 10000.01, double.infinity, double.nan]) {
        expect(CollectorStore.validWeight(w), isFalse);
      }
    },
  );
  test('weight rejects missing and text values', () {
    expect(CollectorStore.validWeight(null), isFalse);
    expect(CollectorStore.validWeight('2'), isFalse);
  });
  group('Unverified Indian mobile contact normalization', () {
    test('accepts ten digits', () {
      expect(
        QuickProfileService.normalizeContactMobile('9876543210'),
        '+919876543210',
      );
    });
    test('accepts country prefix and common separators', () {
      for (final value in [
        '+919876543210',
        '919876543210',
        ' +91 98765 43210 ',
        '(98765)-43210',
      ]) {
        expect(
          QuickProfileService.normalizeContactMobile(value),
          '+919876543210',
          reason: 'Accept a supported contact format',
        );
      }
    });
    test('rejects missing, malformed and non-Indian-format input', () {
      for (final value in [
        '',
        ' ',
        '12345',
        '5876543210',
        '987654321',
        '98765432100',
        '+449876543210',
        '98765abc10',
        '+91+919876543210',
      ]) {
        expect(QuickProfileService.normalizeContactMobile(value), isNull);
      }
    });
  });

  group('Reject invalid input before accessing Firebase', () {
    final service = QuickProfileService();
    test('rejects invalid contact number', () async {
      await expectLater(
        service.continueWithName(
          name: 'Test Collector',
          mobileNumber: '123',
          role: 'collector',
          language: 'en',
        ),
        throwsArgumentError,
      );
    });
    test('rejects blank name', () async {
      await expectLater(
        service.continueWithName(
          name: ' ',
          mobileNumber: '9876543210',
          role: 'collector',
          language: 'hi',
        ),
        throwsArgumentError,
      );
    });
    test('rejects name longer than 100 characters', () async {
      await expectLater(
        service.continueWithName(
          name: List.filled(101, 'a').join(),
          mobileNumber: '9876543210',
          role: 'collector',
          language: 'mr',
        ),
        throwsArgumentError,
      );
    });
    test('rejects invalid role', () async {
      await expectLater(
        service.continueWithName(
          name: 'Test Collector',
          mobileNumber: '9876543210',
          role: 'admin',
          language: 'en',
        ),
        throwsArgumentError,
      );
    });
    test('rejects unsupported language', () async {
      await expectLater(
        service.continueWithName(
          name: 'Test Collector',
          mobileNumber: '9876543210',
          role: 'collector',
          language: 'xx',
        ),
        throwsArgumentError,
      );
    });
  });
}
