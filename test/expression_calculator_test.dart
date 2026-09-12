import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/expression_calculator.dart';

void main() {
  test('the four operators, in the order everybody expects', () {
    expect(calculateExpression('12*7'), '84');
    expect(calculateExpression('2+3*4'), '14');
    expect(calculateExpression('(2+3)*4'), '20');
    expect(calculateExpression('100-1-1'), '98');
    expect(calculateExpression('10/4'), '2.5');
  });

  test('the spellings a phone keyboard actually produces', () {
    expect(calculateExpression('3 × 4'), '12');
    expect(calculateExpression('3 x 4'), '12');
    expect(calculateExpression('12 ÷ 4'), '3');
    expect(calculateExpression('12 : 4'), '3');
    expect(calculateExpression('1,5 + 1,5'), '3');
    expect(calculateExpression('  8  *  8  '), '64');
  });

  test('percent, including the way it is usually said', () {
    expect(calculateExpression('20% * 80'), '16');
    expect(calculateExpression('20% von 80'), '16');
    expect(calculateExpression('20% of 80'), '16');
  });

  test('powers, right to left', () {
    expect(calculateExpression('2^10'), '1024');
    // 2^(3^2) = 2^9, not (2^3)^2 = 64.
    expect(calculateExpression('2^3^2'), '512');
  });

  test('a leading minus is a sign, not a missing number', () {
    expect(calculateExpression('-5+8'), '3');
    expect(calculateExpression('3*-2'), '-6');
  });

  test('the result is rounded to something readable', () {
    // The hardware holds 0.30000000000000004 for this.
    expect(calculateExpression('0.1+0.2'), '0.3');
    expect(calculateExpression('1/3'), '0.333333');
    expect(calculateExpression('10/2'), '5');
  });

  test('anything that is not a sum comes back as nothing', () {
    // The important half: a search field passes everything typed through
    // here, and words must not turn into a stray answer.
    expect(calculateExpression('Kalender'), isNull);
    expect(calculateExpression('whatsapp'), isNull);
    expect(calculateExpression(''), isNull);
    expect(calculateExpression('   '), isNull);
    expect(calculateExpression('2+'), isNull);
    expect(calculateExpression('(2+3'), isNull);
    expect(calculateExpression('2+3)'), isNull);
    expect(calculateExpression('1.2.3+1'), isNull);
  });

  test('a bare number is not a sum either', () {
    // Otherwise looking for the app "2048" would answer itself.
    expect(calculateExpression('2048'), isNull);
    expect(calculateExpression('42'), isNull);
  });

  test('dividing by zero is not an answer', () {
    expect(calculateExpression('5/0'), isNull);
  });
}
