/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/apple_pencil/apple_pencil_interaction.dart';
import 'package:saber/data/tools/stylus_pose.dart';
import 'package:saber/data/tools/stylus_sample.dart';

void main() {
  group('ApplePencilInteractionEvent', () {
    test('parses known hardware gesture and system action', () {
      final event = ApplePencilInteractionEvent.fromPayload({
        'type': 'doubleTap',
        'preferredAction': 'switchEraser',
        'phase': 'ended',
      });

      expect(event?.gesture, ApplePencilHardwareGesture.doubleTap);
      expect(event?.phase, ApplePencilInteractionPhase.ended);
      expect(event?.preferredAction, ApplePencilAction.toggleEraser);
    });

    test('parses squeeze phases', () {
      final event = ApplePencilInteractionEvent.fromPayload({
        'type': 'squeeze',
        'preferredAction': 'showInkAttributes',
        'phase': 'changed',
      });

      expect(event?.gesture, ApplePencilHardwareGesture.squeeze);
      expect(event?.phase, ApplePencilInteractionPhase.changed);
      expect(event?.preferredAction, ApplePencilAction.showInkAttributes);
    });

    test('maps all supported iPadOS preferred actions', () {
      expect(
        ApplePencilAction.fromSystemActionName('ignore'),
        ApplePencilAction.disabled,
      );
      expect(
        ApplePencilAction.fromSystemActionName('switchPrevious'),
        ApplePencilAction.switchPreviousTool,
      );
      expect(
        ApplePencilAction.fromSystemActionName('showColorPalette'),
        ApplePencilAction.showColorPalette,
      );
      expect(
        ApplePencilAction.fromSystemActionName('showContextualPalette'),
        ApplePencilAction.showToolPalette,
      );
      expect(
        ApplePencilAction.fromSystemActionName('runSystemShortcut'),
        ApplePencilAction.runSystemShortcut,
      );
    });

    test('ignores unknown hardware gestures', () {
      final event = ApplePencilInteractionEvent.fromPayload({
        'type': 'singleTap',
        'preferredAction': 'switchEraser',
      });

      expect(event, isNull);
    });

    test('falls back to disabled when system action is unknown', () {
      const event = ApplePencilInteractionEvent(
        gesture: ApplePencilHardwareGesture.squeeze,
        phase: ApplePencilInteractionPhase.began,
        preferredAction: null,
      );

      expect(
        ApplePencilAction.system.resolve(event),
        ApplePencilAction.disabled,
      );
    });

    test('uses Saber override before system action', () {
      const event = ApplePencilInteractionEvent(
        gesture: ApplePencilHardwareGesture.doubleTap,
        preferredAction: ApplePencilAction.toggleEraser,
      );

      expect(
        ApplePencilAction.showColorPalette.resolve(event),
        ApplePencilAction.showColorPalette,
      );
    });
  });

  group('ApplePencilHoverEvent', () {
    test('parses native hover payload', () {
      final event = ApplePencilHoverEvent.fromPayload({
        'phase': 'changed',
        'x': 123,
        'y': 456.5,
        'zOffset': 0.25,
        'azimuthAngle': 1.2,
        'altitudeAngle': 0.8,
        'rollAngle': 0.4,
      });

      expect(event?.phase, ApplePencilInteractionPhase.changed);
      expect(event?.isActive, isTrue);
      expect(event?.position.dx, 123);
      expect(event?.position.dy, 456.5);
      expect(event?.zOffset, 0.25);
      expect(event?.azimuthAngle, 1.2);
      expect(event?.altitudeAngle, 0.8);
      expect(event?.rollAngle, 0.4);
    });

    test('parses ended hover payload as inactive', () {
      final event = ApplePencilHoverEvent.fromPayload({
        'phase': 'ended',
        'x': 1,
        'y': 2,
      });

      expect(event?.isActive, isFalse);
    });

    test('ignores malformed hover payloads', () {
      expect(ApplePencilHoverEvent.fromPayload({'phase': 'changed'}), isNull);
      expect(
        ApplePencilHoverEvent.fromPayload({'phase': 'unknown', 'x': 1, 'y': 2}),
        isNull,
      );
    });
  });

  group('ApplePencilTelemetryEvent', () {
    test(
      'parses native telemetry payload with coalesced and predicted samples',
      () {
        final event = ApplePencilTelemetryEvent.fromPayload({
          'phase': 'changed',
          'x': 10,
          'y': 20,
          'preciseX': 10.25,
          'preciseY': 20.5,
          'timestamp': 100,
          'pressure': 0.7,
          'altitudeAngle': 0.9,
          'azimuthAngle': 1.1,
          'azimuthUnitX': 0.45,
          'azimuthUnitY': 0.89,
          'rollAngle': 0.3,
          'estimatedProperties': 1,
          'sourceFlags': StylusPoseSourceFlags.real,
          'coalesced': [
            {'x': 9, 'y': 19, 'pressure': 0.6},
          ],
          'predicted': [
            {'x': 11, 'y': 21, 'pressure': 0.8},
          ],
        });

        expect(event?.phase, ApplePencilInteractionPhase.changed);
        expect(event?.isActive, isTrue);
        expect(event?.sample.precisePosition.dx, 10.25);
        expect(event?.sample.pressure, 0.7);
        expect(event?.sample.rollAngle, 0.3);
        expect(
          event?.sample.sourceFlags,
          StylusPoseSourceFlags.real | StylusPoseSourceFlags.estimated,
        );
        expect(
          event?.coalescedSamples.single.sourceFlags,
          StylusPoseSourceFlags.coalesced,
        );
        expect(
          event?.predictedSamples.single.sourceFlags,
          StylusPoseSourceFlags.predicted,
        );
      },
    );

    test('converts telemetry sample to stylus sample', () {
      const sample = ApplePencilTelemetrySample(
        position: Offset(1, 2),
        precisePosition: Offset(1.5, 2.5),
        timestamp: 42,
        pressure: 0.4,
        altitudeAngle: 0.8,
        azimuthAngle: 1.2,
        rollAngle: 0.6,
      );

      final stylusSample = sample.toStylusSample();

      expect(stylusSample.isStylus, isTrue);
      expect(stylusSample.pressure, 0.4);
      expect(stylusSample.altitudeAngle, 0.8);
      expect(stylusSample.azimuthAngle, 1.2);
      expect(stylusSample.rollAngle, 0.6);
    });
  });

  group('StylusSample', () {
    test('normalizes stylus pressure and keeps tilt data', () {
      const event = PointerMoveEvent(
        kind: PointerDeviceKind.stylus,
        pressure: 0.75,
        pressureMin: 0,
        pressureMax: 1.5,
        tilt: 0.25,
        orientation: 0.5,
      );

      final sample = StylusSample.fromPointerEvent(event);

      expect(sample.isStylus, isTrue);
      expect(sample.pressure, 0.5);
      expect(sample.tilt, 0.25);
      expect(sample.orientation, 0.5);
    });

    test('converts native fields into a persisted pose', () {
      const sample = StylusSample(
        kind: PointerDeviceKind.stylus,
        timestamp: 12,
        pressure: 0.75,
        altitudeAngle: 0.9,
        azimuthAngle: 1.3,
        rollAngle: 0.4,
      );

      final pose = sample.toPose(strokeStartTimestamp: 10);

      expect(pose?.timestampDelta, 2);
      expect(pose?.pressure, 0.75);
      expect(pose?.altitudeAngle, 0.9);
      expect(pose?.azimuthAngle, 1.3);
      expect(pose?.rollAngle, 0.4);
    });

    test('does not invent pressure for non-stylus pointers', () {
      const event = PointerMoveEvent(kind: PointerDeviceKind.touch);

      final sample = StylusSample.fromPointerEvent(event);

      expect(sample.isStylus, isFalse);
      expect(sample.pressure, isNull);
      expect(sample.tilt, isNull);
      expect(sample.orientation, isNull);
    });
  });
}
