/// Works out `12*7`, `(3+4)/2`, `20% von 80` and the like, so a search
/// field can answer a sum without leaving the launcher.
///
/// Hand-written rather than pulled from a package: the grammar is four
/// operators and a bracket, and a dependency for that would be more code to
/// keep current than the parser is to write. Returns null for anything that
/// isn't a sum, which is the normal case - most of what gets typed into a
/// search field is words.
library;

import 'dart:math' as math;

/// The result of a sum, formatted the way it should be read.
String? calculateExpression(String input) {
  final tokens = _tokenize(input);
  if (tokens == null) return null;
  // A bare number is not a sum. Without this every "2" typed while looking
  // for an app called "2048" would answer itself.
  if (!tokens.any((token) => token is _OperatorToken)) return null;

  final parser = _Parser(tokens);
  final value = parser.parseExpression();
  if (value == null || !parser.atEnd) return null;
  if (value.isNaN || value.isInfinite) return null;
  return formatNumber(value);
}

/// Trims a result down to something readable: whole numbers without a
/// decimal point, the rest to at most six places with the trailing zeros
/// taken off, so 1/3 reads as 0.333333 and 0.1+0.2 as 0.3 rather than as
/// the 0.30000000000000004 the hardware actually holds.
String formatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toInt().toString();
  }
  var text = value.toStringAsFixed(6);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

sealed class _Token {
  const _Token();
}

class _NumberToken extends _Token {
  const _NumberToken(this.value);
  final double value;
}

class _OperatorToken extends _Token {
  const _OperatorToken(this.symbol);
  final String symbol;
}

class _BracketToken extends _Token {
  const _BracketToken(this.open);
  final bool open;
}

/// Null as soon as anything appears that has no place in a sum - that is
/// what tells "12*7" apart from a search for "Kalender".
List<_Token>? _tokenize(String input) {
  // The spellings people actually type, folded onto the ones the parser
  // knows. "von" catches "20% von 80"; the × and ÷ come off a phone keyboard.
  final normalized = input
      .toLowerCase()
      .replaceAll('×', '*')
      .replaceAll('·', '*')
      .replaceAll('x', '*')
      .replaceAll('÷', '/')
      .replaceAll(':', '/')
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll(' von ', '*')
      .replaceAll(' of ', '*')
      .replaceAll(',', '.');

  final tokens = <_Token>[];
  var index = 0;
  while (index < normalized.length) {
    final char = normalized[index];

    if (char == ' ') {
      index++;
      continue;
    }

    if (RegExp(r'[0-9.]').hasMatch(char)) {
      final start = index;
      while (index < normalized.length &&
          RegExp(r'[0-9.]').hasMatch(normalized[index])) {
        index++;
      }
      final number = double.tryParse(normalized.substring(start, index));
      if (number == null) return null;
      tokens.add(_NumberToken(number));
      continue;
    }

    if ('+-*/^%'.contains(char)) {
      tokens.add(_OperatorToken(char));
      index++;
      continue;
    }

    if (char == '(' || char == ')') {
      tokens.add(_BracketToken(char == '('));
      index++;
      continue;
    }

    return null;
  }

  return tokens.isEmpty ? null : tokens;
}

/// Plain recursive descent: sums, then products, then powers, then a single
/// value. Each level only knows the one below it, which is what gives
/// `2+3*4` the 14 everybody expects rather than 20.
class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  int _at = 0;

  bool get atEnd => _at >= _tokens.length;
  _Token? get _current => atEnd ? null : _tokens[_at];

  double? parseExpression() {
    var left = _parseTerm();
    if (left == null) return null;
    while (true) {
      final token = _current;
      if (token is! _OperatorToken) return left;
      if (token.symbol != '+' && token.symbol != '-') return left;
      _at++;
      final right = _parseTerm();
      if (right == null) return null;
      left = token.symbol == '+' ? left! + right : left! - right;
    }
  }

  double? _parseTerm() {
    var left = _parsePower();
    if (left == null) return null;
    while (true) {
      final token = _current;
      if (token is! _OperatorToken) return left;
      if (token.symbol != '*' && token.symbol != '/') return left;
      _at++;
      final right = _parsePower();
      if (right == null) return null;
      // Dividing by zero gives infinity, which calculateExpression drops -
      // an answer of "Infinity" would look like the sum worked.
      left = token.symbol == '*' ? left! * right : left! / right;
    }
  }

  double? _parsePower() {
    final base = _parseUnary();
    if (base == null) return null;
    final token = _current;
    if (token is _OperatorToken && token.symbol == '^') {
      _at++;
      // Right-associative, so 2^3^2 is 2^9 and not 8^2.
      final exponent = _parsePower();
      if (exponent == null) return null;
      return _pow(base, exponent);
    }
    return base;
  }

  double? _parseUnary() {
    final token = _current;
    if (token is _OperatorToken && (token.symbol == '-' || token.symbol == '+')) {
      _at++;
      final value = _parseUnary();
      if (value == null) return null;
      return token.symbol == '-' ? -value : value;
    }
    return _parsePercent();
  }

  /// A percent sign after a number turns it into a hundredth, so "20% * 80"
  /// - which is what "20% von 80" becomes - is 16.
  double? _parsePercent() {
    final value = _parseAtom();
    if (value == null) return null;
    final token = _current;
    if (token is _OperatorToken && token.symbol == '%') {
      _at++;
      return value / 100;
    }
    return value;
  }

  double? _parseAtom() {
    final token = _current;
    if (token is _NumberToken) {
      _at++;
      return token.value;
    }
    if (token is _BracketToken && token.open) {
      _at++;
      final value = parseExpression();
      if (value == null) return null;
      final closing = _current;
      if (closing is! _BracketToken || closing.open) return null;
      _at++;
      return value;
    }
    return null;
  }

  /// A fractional power of a negative number has no real answer. math.pow
  /// gives NaN for it, which calculateExpression drops - so this stays out
  /// of the way and lets that happen.
  static double _pow(double base, double exponent) =>
      math.pow(base, exponent).toDouble();
}
