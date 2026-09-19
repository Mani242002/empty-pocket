/// Safe math expression parser for evaluating arithmetic expressions in amount input fields
class MathExpressionParser {
  /// Evaluates an expression string such as "150 + 50 * 2", "(1200 - 200) / 5", or "2(300 + 50)"
  /// Returns evaluated non-negative double rounded to 2 decimals, or null if expression is invalid or cannot be parsed.
  static double? tryEvaluate(String input) {
    final clean = input.replaceAll(' ', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return null;

    // Direct single number check
    final direct = double.tryParse(clean);
    if (direct != null) {
      if (direct.isNaN || direct.isInfinite || direct < 0) return null;
      return ((direct * 100).roundToDouble()) / 100.0;
    }

    try {
      final tokens = _tokenize(clean);
      if (tokens.isEmpty) return null;

      final rpn = _toRpn(tokens);
      if (rpn == null || rpn.isEmpty) return null;

      final result = _evaluateRpn(rpn);
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

    void flushNumber() {
      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber.toString());
        currentNumber.clear();
      }
    }

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final isDigitOrDot = (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || char == '.';

      if (isDigitOrDot) {
        // Support implicit multiplication like "(100 + 50)2"
        if (currentNumber.isEmpty && tokens.isNotEmpty && tokens.last == ')') {
          tokens.add('*');
        }
        currentNumber.write(char);
      } else if (char == '(') {
        flushNumber();
        // Support implicit multiplication like "2(3+4)" or ")(..."
        if (tokens.isNotEmpty && (tokens.last == ')' || double.tryParse(tokens.last) != null)) {
          tokens.add('*');
        }
        tokens.add('(');
      } else if (char == ')') {
        flushNumber();
        tokens.add(')');
      } else if (char == '+' || char == '-' || char == '*' || char == 'x' || char == 'X' || char == '/') {
        if (currentNumber.isEmpty && char == '-') {
          // Negative unary prefix (e.g. at start or after operator/open-parenthesis)
          if (tokens.isEmpty || tokens.last == '(' || _isOperator(tokens.last)) {
            currentNumber.write(char);
            continue;
          }
        }
        flushNumber();
        tokens.add(char == 'x' || char == 'X' ? '*' : char);
      } else {
        // Unrecognized character -> invalid expression
        return [];
      }
    }

    flushNumber();
    return tokens;
  }

  static bool _isOperator(String token) {
    return token == '+' || token == '-' || token == '*' || token == '/';
  }

  static int _precedence(String op) {
    if (op == '+' || op == '-') return 1;
    if (op == '*' || op == '/') return 2;
    return 0;
  }

  /// Converts infix tokens to postfix (Reverse Polish Notation) using Shunting-yard algorithm
  static List<String>? _toRpn(List<String> tokens) {
    final List<String> output = [];
    final List<String> opStack = [];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '(') {
        opStack.add(token);
      } else if (token == ')') {
        bool foundOpen = false;
        while (opStack.isNotEmpty) {
          final top = opStack.removeLast();
          if (top == '(') {
            foundOpen = true;
            break;
          }
          output.add(top);
        }
        if (!foundOpen) return null; // Mismatched closing parenthesis
      } else if (_isOperator(token)) {
        while (opStack.isNotEmpty &&
            opStack.last != '(' &&
            _precedence(opStack.last) >= _precedence(token)) {
          output.add(opStack.removeLast());
        }
        opStack.add(token);
      } else {
        // Operand (number)
        final num = double.tryParse(token);
        if (num == null) return null;
        output.add(token);
      }
    }

    while (opStack.isNotEmpty) {
      final top = opStack.removeLast();
      if (top == '(' || top == ')') return null; // Mismatched opening parenthesis
      output.add(top);
    }

    return output;
  }

  /// Evaluates an RPN token list
  static double? _evaluateRpn(List<String> rpn) {
    final List<double> stack = [];

    for (final token in rpn) {
      if (_isOperator(token)) {
        if (stack.length < 2) return null;
        final right = stack.removeLast();
        final left = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(left + right);
            break;
          case '-':
            stack.add(left - right);
            break;
          case '*':
            stack.add(left * right);
            break;
          case '/':
            if (right == 0.0) return null; // Prevent division by zero
            stack.add(left / right);
            break;
          default:
            return null;
        }
      } else {
        final val = double.tryParse(token);
        if (val == null) return null;
        stack.add(val);
      }
    }

    if (stack.length != 1) return null;
    return stack.single;
  }
}
