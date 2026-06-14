/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:stow_codecs/stow_codecs.dart';

/// A hardware gesture emitted by an Apple Pencil body interaction.
enum ApplePencilHardwareGesture {
  /// The user double-tapped the side of an Apple Pencil.
  doubleTap,

  /// The user squeezed an Apple Pencil Pro.
  squeeze;

  /// Parses a hardware gesture name emitted by the iOS bridge.
  static ApplePencilHardwareGesture? fromName(String? name) {
    return switch (name) {
      'doubleTap' => doubleTap,
      'squeeze' => squeeze,
      _ => null,
    };
  }
}

/// A lifecycle phase for an Apple Pencil hardware interaction.
enum ApplePencilInteractionPhase {
  /// A continuous gesture has started.
  began,

  /// A continuous gesture has changed.
  changed,

  /// A continuous gesture has ended, or a discrete gesture was recognized.
  ended,

  /// A continuous gesture was cancelled.
  cancelled;

  /// Parses an interaction phase name emitted by the iOS bridge.
  static ApplePencilInteractionPhase? fromName(String? name) {
    return switch (name) {
      'began' => began,
      'changed' => changed,
      'ended' => ended,
      'cancelled' => cancelled,
      _ => null,
    };
  }
}

/// A parsed Apple Pencil hover event from the native iOS bridge.
class ApplePencilHoverEvent {
  /// Creates a parsed Apple Pencil hover event.
  const ApplePencilHoverEvent({
    required this.position,
    required this.phase,
    this.zOffset,
    this.azimuthAngle,
    this.altitudeAngle,
    this.rollAngle,
  });

  /// The hover location in Flutter view coordinates.
  final Offset position;

  /// The lifecycle phase of the hover gesture.
  final ApplePencilInteractionPhase phase;

  /// The normalized distance from the screen, where 0 is closest and 1 is farthest.
  final double? zOffset;

  /// The azimuth angle in radians.
  final double? azimuthAngle;

  /// The altitude angle in radians.
  final double? altitudeAngle;

  /// The Pencil Pro roll angle in radians, when supported.
  final double? rollAngle;

  /// Whether this event should show or update the hover preview.
  bool get isActive =>
      phase == ApplePencilInteractionPhase.began ||
      phase == ApplePencilInteractionPhase.changed;

  /// Parses a hover payload emitted by the iOS EventChannel.
  static ApplePencilHoverEvent? fromPayload(Object? payload) {
    if (payload is! Map) return null;

    final x = _numberToDouble(payload['x']);
    final y = _numberToDouble(payload['y']);
    if (x == null || y == null) return null;

    final phase = ApplePencilInteractionPhase.fromName(
      payload['phase'] is String ? payload['phase'] as String : null,
    );
    if (phase == null) return null;

    return ApplePencilHoverEvent(
      position: Offset(x, y),
      phase: phase,
      zOffset: _numberToDouble(payload['zOffset']),
      azimuthAngle: _numberToDouble(payload['azimuthAngle']),
      altitudeAngle: _numberToDouble(payload['altitudeAngle']),
      rollAngle: _numberToDouble(payload['rollAngle']),
    );
  }

  static double? _numberToDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }
}

/// A Saber action that can be bound to an Apple Pencil hardware gesture.
enum ApplePencilAction {
  /// Follow the current iPadOS Apple Pencil system preference.
  system,

  /// Do nothing.
  disabled,

  /// Toggle between the eraser and the last non-eraser tool.
  toggleEraser,

  /// Switch to the previous non-transient tool.
  switchPreviousTool,

  /// Show Saber's color palette.
  showColorPalette,

  /// Show Saber's ink attributes for the current tool.
  showInkAttributes,

  /// Show Saber's tool palette.
  showToolPalette,

  /// Run the iPadOS Shortcut selected in system settings.
  runSystemShortcut;

  /// Codec used by Stow-backed preferences.
  static const codec = EnumCodec(values);

  /// Converts an iPadOS preferred Pencil action name into a Saber action.
  static ApplePencilAction? fromSystemActionName(String? name) {
    return switch (name) {
      'ignore' || 'disabled' || 'off' => disabled,
      'switchEraser' => toggleEraser,
      'switchPrevious' => switchPreviousTool,
      'showColorPalette' => showColorPalette,
      'showInkAttributes' => showInkAttributes,
      'showToolPalette' ||
      'showContextualPalette' ||
      'showPalette' => showToolPalette,
      'runSystemShortcut' => runSystemShortcut,
      _ => null,
    };
  }

  /// Resolves this preference against an event's system-preferred action.
  ApplePencilAction resolve(ApplePencilInteractionEvent event) {
    if (this != system) return this;
    return event.preferredAction ?? disabled;
  }
}

/// A parsed Apple Pencil hardware interaction from the native iOS bridge.
class ApplePencilInteractionEvent {
  /// Creates a parsed Apple Pencil interaction event.
  const ApplePencilInteractionEvent({
    required this.gesture,
    required this.preferredAction,
    this.phase = ApplePencilInteractionPhase.ended,
  });

  /// The hardware gesture that occurred.
  final ApplePencilHardwareGesture gesture;

  /// The action requested by iPadOS system settings, when known.
  final ApplePencilAction? preferredAction;

  /// The lifecycle phase of this interaction.
  final ApplePencilInteractionPhase phase;

  /// Parses an event payload emitted by the iOS EventChannel.
  static ApplePencilInteractionEvent? fromPayload(Object? payload) {
    if (payload is! Map) return null;

    final type = payload['type'];
    final preferredAction = payload['preferredAction'];
    final gesture = ApplePencilHardwareGesture.fromName(
      type is String ? type : null,
    );
    if (gesture == null) return null;

    final phase = _parsePhase(payload['phase'], gesture);
    if (phase == null) return null;

    return ApplePencilInteractionEvent(
      gesture: gesture,
      phase: phase,
      preferredAction: ApplePencilAction.fromSystemActionName(
        preferredAction is String ? preferredAction : null,
      ),
    );
  }

  static ApplePencilInteractionPhase? _parsePhase(
    Object? value,
    ApplePencilHardwareGesture gesture,
  ) {
    if (value is String) return ApplePencilInteractionPhase.fromName(value);

    return switch (gesture) {
      ApplePencilHardwareGesture.doubleTap => ApplePencilInteractionPhase.ended,
      ApplePencilHardwareGesture.squeeze => ApplePencilInteractionPhase.began,
    };
  }
}

/// Provides Apple Pencil hardware interaction events.
abstract class ApplePencilInteractionService {
  /// The stream of Apple Pencil hardware interaction events.
  Stream<ApplePencilInteractionEvent> get events;
}

/// Provides Apple Pencil hover events.
abstract class ApplePencilHoverService {
  /// The stream of Apple Pencil hover events.
  Stream<ApplePencilHoverEvent> get events;
}

/// Apple Pencil interaction service backed by an iOS EventChannel.
class EventChannelApplePencilInteractionService
    implements ApplePencilInteractionService {
  /// Creates an EventChannel-backed Apple Pencil interaction service.
  const EventChannelApplePencilInteractionService();

  static final _log = Logger('ApplePencilInteraction');
  static const _eventChannel = EventChannel(
    'saber/apple_pencil_interaction/events',
  );

  @override
  Stream<ApplePencilInteractionEvent> get events {
    if (!Platform.isIOS) return const Stream.empty();

    return _eventChannel.receiveBroadcastStream().transform(
      StreamTransformer<dynamic, ApplePencilInteractionEvent>.fromHandlers(
        handleData: (payload, sink) {
          final event = ApplePencilInteractionEvent.fromPayload(payload);
          if (event == null) {
            _log.warning('Invalid Apple Pencil interaction payload: $payload');
            return;
          }
          sink.add(event);
        },
        handleError: (error, stackTrace, sink) {
          _log.warning(
            'Apple Pencil interaction stream failed',
            error,
            stackTrace,
          );
        },
      ),
    );
  }
}

/// Apple Pencil hover service backed by an iOS EventChannel.
class EventChannelApplePencilHoverService implements ApplePencilHoverService {
  /// Creates an EventChannel-backed Apple Pencil hover service.
  const EventChannelApplePencilHoverService();

  static final _log = Logger('ApplePencilHover');
  static const _eventChannel = EventChannel('saber/apple_pencil_hover/events');

  @override
  Stream<ApplePencilHoverEvent> get events {
    if (!Platform.isIOS) return const Stream.empty();

    return _eventChannel.receiveBroadcastStream().transform(
      StreamTransformer<dynamic, ApplePencilHoverEvent>.fromHandlers(
        handleData: (payload, sink) {
          final event = ApplePencilHoverEvent.fromPayload(payload);
          if (event == null) {
            _log.warning('Invalid Apple Pencil hover payload: $payload');
            return;
          }
          sink.add(event);
        },
        handleError: (error, stackTrace, sink) {
          _log.warning('Apple Pencil hover stream failed', error, stackTrace);
        },
      ),
    );
  }
}
