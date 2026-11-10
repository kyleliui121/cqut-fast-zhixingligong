import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/core/nonce.dart';

void main() {
  test('10 and 14 digit nonces stay within nextInt bounds', () {
    final rng = math.Random(12345);
    for (final digits in <int>[10, 14]) {
      for (var i = 0; i < 1000; i++) {
        final nonce = numericNonce(rng, digits);
        expect(nonce.length, digits);
        expect(RegExp(r'^[1-9][0-9]*$').hasMatch(nonce), isTrue);
      }
    }
  });

  test('invalid nonce length is rejected', () {
    expect(() => numericNonce(math.Random(0), 0), throwsArgumentError);
  });
}
