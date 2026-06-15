/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/stylus_sample.dart';
import 'package:sbn/tool_id.dart';

void main() {
  group('pressure curve', () {
    test('keeps neutral pressure unchanged', () {
      final curve = PressureCurve.neutral();

      expect(Pen.applyPressureCurve(0.25, curve), moreOrLessEquals(0.25));
      expect(Pen.applyPressureCurve(0.75, curve), moreOrLessEquals(0.75));
    });

    test('smooths through user control points without decreasing', () {
      final curve = PressureCurve([
        const PressureCurvePoint(input: 0, output: 0),
        const PressureCurvePoint(input: 0.5, output: 0.8),
        const PressureCurvePoint(input: 1, output: 1),
      ]);

      expect(Pen.applyPressureCurve(0.5, curve), moreOrLessEquals(0.8));

      var previous = Pen.applyPressureCurve(0, curve)!;
      for (var i = 1; i <= 100; i++) {
        final current = Pen.applyPressureCurve(i / 100, curve)!;
        expect(current, greaterThanOrEqualTo(previous));
        previous = current;
      }
    });

    test('legacy positive curve raises output pressure percentage', () {
      final curve = PressureCurve.fromLegacyCurve(0.6);
      final output = Pen.applyPressureCurve(0.25, curve);

      expect(output, greaterThan(0.25));
    });

    test('legacy negative curve lowers output pressure percentage', () {
      final curve = PressureCurve.fromLegacyCurve(-0.6);
      final output = Pen.applyPressureCurve(0.25, curve);

      expect(output, lessThan(0.25));
    });

    test('clamps pressure and control points to percentage bounds', () {
      final curve = PressureCurve([
        const PressureCurvePoint(input: -0.5, output: -0.5),
        const PressureCurvePoint(input: 1.5, output: 1.5),
      ]);

      expect(Pen.applyPressureCurve(-0.5, curve), 0);
      expect(Pen.applyPressureCurve(1.5, curve), 1);
    });

    test('treats zero-output segments as pressure dead zones', () {
      final curve = PressureCurve([
        const PressureCurvePoint(input: 0, output: 0),
        const PressureCurvePoint(input: 0.3, output: 0),
        const PressureCurvePoint(input: 1, output: 1),
      ]);

      expect(curve.isDeadZone(0.2), isTrue);
      expect(Pen.applyPressureCurve(0.2, curve), isNull);
      expect(curve.isDeadZone(0.31), isFalse);
      expect(Pen.applyPressureCurve(0.31, curve), greaterThan(0));
    });

    test('pressure dead zones split strokes instead of connecting gaps', () {
      final page = EditorPage(size: const Size(400, 400));
      final pen = Pen(
        name: 'Test pen',
        sizeMin: 1,
        sizeMax: 25,
        sizeStep: 1,
        icon: Pen.fountainPenIcon,
        options: StrokeOptions(size: 5),
        pressureEnabled: true,
        pressureCurve: PressureCurve([
          const PressureCurvePoint(input: 0, output: 0),
          const PressureCurvePoint(input: 0.3, output: 0),
          const PressureCurvePoint(input: 1, output: 1),
        ]),
        tiltSensitivity: 0,
        rollSensitivity: 0,
        color: const Color(0xff000000),
        toolId: ToolId.fountainPen,
      );

      pen.onDragStart(
        Offset.zero,
        page,
        0,
        const StylusSample(kind: PointerDeviceKind.stylus, pressure: 0.5),
      );
      final firstSegment = pen.onDragUpdate(
        const Offset(10, 0),
        const StylusSample(kind: PointerDeviceKind.stylus, pressure: 0.1),
      );
      pen.onDragUpdate(
        const Offset(20, 0),
        const StylusSample(kind: PointerDeviceKind.stylus, pressure: 0.6),
      );
      final secondSegment = pen.onDragEnd();

      expect(firstSegment, isNotNull);
      expect(firstSegment!.length, 1);
      expect(secondSegment, isNotNull);
      expect(secondSegment!.length, 1);
      expect(Pen.currentStroke, isNull);
    });
  });
}
