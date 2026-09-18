import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/services/ai_service.dart';

void main() {
  group('AiService.stripThinkingTags', () {
    test('removes standard <think>...</think> blocks', () {
      const input = '''
<think>
1. Analyze the User's Input: The user said "hi".
2. Analyze the Context:
   - Role: PocketAI
3. Determine the Goal: Acknowledge warmly.
4. Drafting the Response: "Hello there!"
Let's go.
</think>
Hello! 👋

How can I assist you with your finances today?''';

      final result = AiService.stripThinkingTags(input);
      expect(result, equals('Hello! 👋\n\nHow can I assist you with your finances today?'));
    });

    test('removes thinking text when opening tag is omitted by tokenizer', () {
      const input = '''
1. Analyze the User's Input: The user said "hi".
2. Analyze the Context:
Let's go. </think>
Hello! 👋

I see your financial dashboard is currently a blank slate (all metrics are at ₹0.00).''';

      final result = AiService.stripThinkingTags(input);
      expect(
        result,
        equals('Hello! 👋\n\nI see your financial dashboard is currently a blank slate (all metrics are at ₹0.00).'),
      );
    });

    test('removes <thought>, <thinking>, <reasoning> tags case-insensitively', () {
      const input1 = '<THOUGHT>Secret thoughts</THOUGHT>Final message';
      const input2 = '<reasoning>Some chain of thought</reasoning>Actual recommendation: Save 20%';
      const input3 = '<Thinking>\nStep 1: Check budget\n</Thinking>\nHere is your budget.';

      expect(AiService.stripThinkingTags(input1), equals('Final message'));
      expect(AiService.stripThinkingTags(input2), equals('Actual recommendation: Save 20%'));
      expect(AiService.stripThinkingTags(input3), equals('Here is your budget.'));
    });

    test('handles multiple thinking blocks', () {
      const input = '''
<think>Thought 1</think>
Part 1 of answer.
<think>Thought 2</think>
Part 2 of answer.''';

      final result = AiService.stripThinkingTags(input);
      expect(result, equals('Part 1 of answer.\n\nPart 2 of answer.'));
    });

    test('handles text without any thinking tags without modification', () {
      const input = 'Hello! How can I help you?';
      expect(AiService.stripThinkingTags(input), equals('Hello! How can I help you?'));
    });
  });

  group('AiService.parseAuditResponse', () {
    test('extracts executive overview, strengths, risks, and recommendations accurately', () {
      const sampleLlmResponse = '''
EXECUTIVE OVERVIEW
Your overall cash balance is stable with a healthy savings rate of 35%.

KEY STRENGTHS
* Consistent monthly investments in mutual funds.
* Emergency reserve covers over 4 months of essential expenses.
* No overdue debt or credit card rollover interest.

RISK FLAGS
- High dining out expenses exceeding monthly budget by 15%.
- Unhedged liability balance on personal loan.

ACTIONABLE RECOMMENDATIONS
1. Automate SIP transfers on salary day.
2. Reduce discretionary dining expenses by 10%.
3. Prepay high-interest personal loan principal.
''';

      final report = AiService.parseAuditResponse(sampleLlmResponse);

      expect(report.overview, contains('Your overall cash balance is stable'));
      expect(report.strengths.length, equals(3));
      expect(report.strengths.first, contains('Consistent monthly investments'));
      expect(report.risks.length, equals(2));
      expect(report.risks.first, contains('High dining out expenses'));
      expect(report.recommendations.length, equals(3));
      expect(report.recommendations.first, contains('Automate SIP transfers'));
    });

    test('falls back gracefully to safe defaults when LLM output lacks explicit headings', () {
      const unstructuredText = 'You are doing great with your money. Keep saving consistently.';

      final report = AiService.parseAuditResponse(unstructuredText);

      expect(report.overview, contains('You are doing great with your money'));
      expect(report.strengths, isNotEmpty);
      expect(report.risks, isNotEmpty);
      expect(report.recommendations, isNotEmpty);
    });
  });
}
