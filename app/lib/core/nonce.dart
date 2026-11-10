import 'dart:math' as math;

/// Generates a decimal nonce with exactly [digits] characters.
/// Random.nextInt only accepts small upper bounds (up to 2^32); do not
/// attempt to generate long decimal nonces with nextInt(pow(10, digits)).
String numericNonce(math.Random random, int digits) {
  if (digits < 1) {
    throw ArgumentError.value(digits, 'digits', 'must be positive');
  }
  final result = StringBuffer(random.nextInt(9) + 1);
  for (var i = 1; i < digits; i++) {
    result.write(random.nextInt(10));
  }
  return result.toString();
}
