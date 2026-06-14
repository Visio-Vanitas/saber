/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/apple_pencil/apple_pencil_interaction.dart';
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
