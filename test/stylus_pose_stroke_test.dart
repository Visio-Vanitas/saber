/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/stylus_pose.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

void main() {
  const page = HasSize(Size(400, 400));

  test('serializes and parses v20 stylus pose samples', () {
    final stroke =
        Stroke(
            color: Stroke.defaultColor,
            pressureEnabled: true,
            options: StrokeOptions(size: 5),
            pageIndex: 0,
            page: page,
            toolId: ToolId.fountainPen,
          )
          ..addPoint(
            const Offset(1, 2),
            0.5,
            const StylusPose(
              timestampDelta: 0.02,
              pressure: 0.5,
              altitudeAngle: 0.8,
              azimuthAngle: 1.1,
              azimuthUnitX: 0.45,
              azimuthUnitY: 0.89,
              rollAngle: 0.4,
              sourceFlags: StylusPoseSourceFlags.coalesced,
            ),
          )
          ..addPoint(const Offset(3, 4), 0.6);

    final json = stroke.toJson();

    expect(json['ap'], isA<List<Object?>>());
    expect((json['ap'] as List<Object?>).length, 2);

    final parsed = Stroke.fromJson(
      json,
      fileVersion: 20,
      pageIndex: 0,
      page: page,
    );

    expect(parsed.stylusPoses.length, 2);
    expect(parsed.stylusPoses[0]?.timestampDelta, closeTo(0.02, 0.0001));
    expect(parsed.stylusPoses[0]?.pressure, closeTo(0.5, 0.0001));
    expect(parsed.stylusPoses[0]?.altitudeAngle, closeTo(0.8, 0.0001));
    expect(parsed.stylusPoses[0]?.azimuthAngle, closeTo(1.1, 0.0001));
    expect(parsed.stylusPoses[0]?.rollAngle, closeTo(0.4, 0.0001));
    expect(parsed.stylusPoses[0]?.sourceFlags, StylusPoseSourceFlags.coalesced);
    expect(parsed.stylusPoses[1], isNull);
  });

  test('omits stylus pose field when stroke has no pose data', () {
    final stroke = Stroke(
      color: Stroke.defaultColor,
      pressureEnabled: true,
      options: StrokeOptions(size: 5),
      pageIndex: 0,
      page: page,
      toolId: ToolId.fountainPen,
    )..addPoint(const Offset(1, 2), 0.5);

    expect(stroke.toJson(), isNot(contains('ap')));
  });

  test('mirrors native Apple Pencil roll for canvas rendering', () {
    expect(StylusPose.canvasAngleFromNativeRoll(0.4), closeTo(-0.4, 0.0001));
    expect(
      StylusPose.averageCanvasRoll([
        const StylusPose(rollAngle: 0.4),
        const StylusPose(rollAngle: 0.4),
      ]),
      closeTo(-0.4, 0.0001),
    );
  });

  test('uses Apple Pencil Pro roll to shape fountain pen nib angle', () {
    final horizontalNib = _rollAwareStroke(rollAngle: 0);
    final verticalNib = _rollAwareStroke(rollAngle: pi / 2);

    final horizontalBounds = horizontalNib.highQualityPath.getBounds();
    final verticalBounds = verticalNib.highQualityPath.getBounds();

    expect(horizontalBounds.width, isNot(verticalBounds.width));
    expect(horizontalBounds.height, isNot(verticalBounds.height));
  });

  test(
    'keeps fountain pen stroke from collapsing when roll follows motion',
    () {
      final stroke =
          Stroke(
              color: Stroke.defaultColor,
              pressureEnabled: true,
              options: StrokeOptions(size: 10),
              pageIndex: 0,
              page: page,
              toolId: ToolId.fountainPen,
            )
            ..addPoint(
              const Offset(10, 20),
              0.5,
              const StylusPose(pressure: 0.5, rollAngle: 0),
            )
            ..addPoint(
              const Offset(50, 20),
              0.5,
              const StylusPose(pressure: 0.5, rollAngle: 0),
            );

      expect(stroke.highQualityPath.getBounds().height, greaterThan(3));
    },
  );

  test('keeps crossed fountain pen strokes filled at the intersection', () {
    final stroke =
        Stroke(
            color: Stroke.defaultColor,
            pressureEnabled: true,
            options: StrokeOptions(size: 8),
            pageIndex: 0,
            page: page,
            toolId: ToolId.fountainPen,
          )
          ..addPoint(
            const Offset(10, 10),
            0.5,
            const StylusPose(pressure: 0.5, rollAngle: 0),
          )
          ..addPoint(
            const Offset(30, 30),
            0.5,
            const StylusPose(pressure: 0.5, rollAngle: 0),
          )
          ..addPoint(
            const Offset(10, 30),
            0.5,
            const StylusPose(pressure: 0.5, rollAngle: 0),
          )
          ..addPoint(
            const Offset(30, 10),
            0.5,
            const StylusPose(pressure: 0.5, rollAngle: 0),
          );

    expect(stroke.highQualityPath.contains(const Offset(20, 20)), isTrue);
  });
}

Stroke _rollAwareStroke({required double rollAngle}) {
  return Stroke(
      color: Stroke.defaultColor,
      pressureEnabled: true,
      options: StrokeOptions(size: 10),
      pageIndex: 0,
      page: const HasSize(Size(400, 400)),
      toolId: ToolId.fountainPen,
    )
    ..addPoint(
      const Offset(10, 10),
      0.5,
      StylusPose(pressure: 0.5, rollAngle: rollAngle),
    )
    ..addPoint(
      const Offset(20, 20),
      0.5,
      StylusPose(pressure: 0.5, rollAngle: rollAngle),
    );
}
