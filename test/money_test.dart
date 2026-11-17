import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_ai/domain/money.dart';

void main() {
  test('MYR decimal input converts to integer sen exactly', () {
    expect(Money.parse('0.01'), 1);
    expect(Money.parse('12.5'), 1250);
    expect(Money.parse(' 123.45 '), 12345);
    expect(Money.parse('9999999999.99'), Money.maxSen);
    expect(Money.parse('0'), 0);
    for (final value in ['', '-1', '1.001', 'NaN', '1e3', '1,000', '.50', '1.', '10000000000']) {
      expect(() => Money.parse(value), throwsFormatException);
    }
  });
}
