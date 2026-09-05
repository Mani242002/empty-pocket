/// Safe math expression parser for evaluating arithmetic expressions in amount input fields
class MathExpressionParser {
  /// Evaluates an expression string such as "150 + 50 * 2" or "1200 / 3"
  /// Returns evaluated double, or null if expression is invalid or cannot be parsed.
  static double? tryEvaluate(String input) {
    final clean = input.replaceAll(' ', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return null;

    // Direct single number
    final direct = double.tryParse(clean);
    if (direct != null) {
      if (direct.isNaN || direct.isInfinite || direct < 0) return null;
      return direct;
    }

    try {
      final tokens = _tokenize(clean);
      if (tokens.isEmpty) return null;
      final result = _parseExpression(tokens);
      if (result == null || result.isNaN || result.isInfinite || result < 0) {
        return null;
      }
      return ((result * 100).roundToDouble()) / 100.0;
    } catch (_) {
      return null;
    }
  }

  static List<String> _tokenize(String input) {
    final List<String> tokens = [];
    final StringBuffer currentNumber = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if ((char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || char == '.') {
        currentNumber.write(char);
      } else if (char == '+' || char == '-' || char == '*' || char == 'x' || char == 'X' || char == '/') {
        if (currentNumber.isNotEmpty) {
          tokens.add(currentNumber.toString());
          currentNumber.clear();
        } else if (char == '-' && (tokens.isEmpty || _isOperator(tokens.last))) {
          // Negative unary prefix
          currentNumber.write(char);
          continue;
        }
        tokens.add(char == 'x' || char == 'X' ? '*' : char);
      } else {
        // Invalid character
        return [];
      }
    }

    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber.toString());
    }

    return tokens;
  }

  static bool _isOperator(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  static double? _parseExpression(List<String> tokens) {
    if (tokens.isEmpty) return null;

    // Step 1: Process multiplication and division first (standard BODMAS/operator precedence)
    final List<String> pass1 = [];
    int i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token == '*' || token == '/') {
        if (pass1.isEmpty || i + 1 >= tokens.length) return null;
        final left = double.tryParse(pass1.removeLast());
        final right = double.tryParse(tokens[i + 1]);
        if (left == null || right == null) return null;

        if (token == '/') {
          if (right == 0.0) return null; // Prevent zero division
          pass1.add((left / right).toString());
        } else {
          pass1.add((left * right).toString());
        }
        i += 2;
      } else {
        pass1.add(token);
        i++;
      }
    }

    if (pass1.isEmpty) return null;

    // Step 2: Process addition and subtraction
    double result = double.tryParse(pass1[0]) ?? 0.0;
    int j = 1;
    while (j < pass1.length) {
      final op = pass1[j];
      if (j + 1 >= pass1.length) return null;
      final nextVal = double.tryParse(pass1[j + 1]);
      if (nextVal == null) return null;

      if (op == '+') {
        result += nextVal;
      } else if (op == '-') {
        result -= nextVal;
      } else {
        return null;
      }
      j += 2;
    }

    return result;
  }
}
