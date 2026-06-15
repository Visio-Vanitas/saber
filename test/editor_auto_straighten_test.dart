/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/pages/editor/editor.dart';

void main() {
  group('continuous writing auto-straighten suppression', () {
    test('does not suppress the first stroke', () {
      expect(
        EditorState.shouldSuppressAutoStraightenForContinuousWriting(
          previousStrokeEndedAt: null,
          currentStrokeStartedAt: DateTime(2026),
        ),
        isFalse,
      );
    });

    test('suppresses strokes started soon after the previous stroke', () {
      final previousStrokeEndedAt = DateTime(2026);

      expect(
        EditorState.shouldSuppressAutoStraightenForContinuousWriting(
          previousStrokeEndedAt: previousStrokeEndedAt,
          currentStrokeStartedAt: previousStrokeEndedAt.add(
            const Duration(milliseconds: 300),
          ),
        ),
        isTrue,
      );
    });

    test('restores auto-straighten after a pause', () {
      final previousStrokeEndedAt = DateTime(2026);

      expect(
        EditorState.shouldSuppressAutoStraightenForContinuousWriting(
          previousStrokeEndedAt: previousStrokeEndedAt,
          currentStrokeStartedAt: previousStrokeEndedAt.add(
            EditorState.continuousWritingAutoStraightenSuppressionWindow +
                const Duration(milliseconds: 1),
          ),
        ),
        isFalse,
      );
    });

    test('does not suppress auto-straighten when the window is disabled', () {
      final previousStrokeEndedAt = DateTime(2026);

      expect(
        EditorState.shouldSuppressAutoStraightenForContinuousWriting(
          previousStrokeEndedAt: previousStrokeEndedAt,
          currentStrokeStartedAt: previousStrokeEndedAt.add(
            const Duration(milliseconds: 1),
          ),
          window: Duration.zero,
        ),
        isFalse,
      );
    });
  });
}
