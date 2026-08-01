import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/widget_element.dart';

void main() {
  test('the range includes both ends', () {
    const rule = IconRule(min: 0, max: 2, iconName: 'sunny');
    expect(rule.matches('0'), isTrue);
    expect(rule.matches('1'), isTrue);
    expect(rule.matches('2'), isTrue);
    expect(rule.matches('3'), isFalse);
  });

  test('a rule without bounds catches anything numeric', () {
    const rule = IconRule(iconName: 'cloudy');
    expect(rule.matches('61'), isTrue);
    expect(rule.matches('-'), isFalse);
  });

  test('the number is found even with something around it', () {
    const rule = IconRule(min: 0, max: 2, iconName: 'sunny');
    expect(rule.matches(' 2 '), isTrue);
    expect(rule.matches('2 °C'), isTrue);
    expect(rule.matches('2.0'), isTrue);
  });

  test('an exact match ignores the range', () {
    const rule = IconRule(equals: 'Regen', iconName: 'rain');
    expect(rule.matches('regen'), isTrue);
    expect(rule.matches('Schnee'), isFalse);
  });
}
