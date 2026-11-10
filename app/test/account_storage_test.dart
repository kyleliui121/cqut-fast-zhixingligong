import 'package:flutter_test/flutter_test.dart';
import 'package:zhixing_flash/models.dart';

void main() {
  test('account JSON excludes passwords after migration', () {
    final legacy = Account.fromJson(<String, dynamic>{
      'username': 'student',
      'displayName': 'Example',
      'password': 'legacy-plaintext-should-be-erased',
    });
    expect(legacy.password, isEmpty);
    expect(legacy.toJson()['username'], 'student');
    expect(legacy.toJson().containsKey('password'), isFalse);
  });
}
