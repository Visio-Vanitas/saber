/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/tools/stylus_pose.dart';
import 'package:saber/data/tools/stylus_sample.dart';
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

/// A native Apple Pencil touch sample emitted by the iOS telemetry bridge.
class ApplePencilTelemetrySample {
  /// Creates a native Apple Pencil telemetry sample.
  const ApplePencilTelemetrySample({
    required this.position,
    required this.precisePosition,
    this.timestamp,
    this.pressure,
    this.force,
    this.maximumPossibleForce,
    this.altitudeAngle,
    this.azimuthAngle,
    this.azimuthUnitX,
    this.azimuthUnitY,
    this.rollAngle,
    this.majorRadius,
    this.majorRadiusTolerance,
    this.estimatedProperties,
    this.estimatedPropertiesExpectingUpdates,
    this.sourceFlags = StylusPoseSourceFlags.real,
  });

  /// The sample location in Flutter view coordinates.
  final Offset position;

  /// The precise sample location in Flutter view coordinates.
  final Offset precisePosition;

  /// The native event timestamp.
  final double? timestamp;

  /// Normalized native pressure in the range 0 to 1.
  final double? pressure;

  /// Raw native force.
  final double? force;

  /// Maximum possible native force.
  final double? maximumPossibleForce;

  /// Native altitude angle in radians.
  final double? altitudeAngle;

  /// Native azimuth angle in radians.
  final double? azimuthAngle;

  /// Native azimuth unit vector x component.
  final double? azimuthUnitX;

  /// Native azimuth unit vector y component.
  final double? azimuthUnitY;

  /// Native Apple Pencil Pro roll angle in radians.
  final double? rollAngle;

  /// Native major touch radius.
  final double? majorRadius;

  /// Native major touch radius tolerance.
  final double? majorRadiusTolerance;

  /// UIKit estimated property bitset.
  final int? estimatedProperties;

  /// UIKit estimated properties still expecting updates.
  final int? estimatedPropertiesExpectingUpdates;

  /// Bit flags describing the sample source.
  final int sourceFlags;

  /// Converts this telemetry sample into the editor's current stylus sample.
  StylusSample toStylusSample() => StylusSample(
    kind: PointerDeviceKind.stylus,
    pressure: pressure,
    timestamp: timestamp,
    altitudeAngle: altitudeAngle,
    azimuthAngle: azimuthAngle,
    azimuthUnitX: azimuthUnitX,
    azimuthUnitY: azimuthUnitY,
    rollAngle: rollAngle,
    sourceFlags: sourceFlags,
  );

  /// Converts this telemetry sample into a persisted pose sample.
  StylusPose? toPose({double? strokeStartTimestamp}) =>
      toStylusSample().toPose(strokeStartTimestamp: strokeStartTimestamp);

  /// Parses a telemetry sample payload emitted by the iOS EventChannel.
  static ApplePencilTelemetrySample? fromPayload(
    Object? payload, {
    int? fallbackSourceFlags,
  }) {
    if (payload is! Map) return null;

    final x = _numberToDouble(payload['x']);
    final y = _numberToDouble(payload['y']);
    if (x == null || y == null) return null;

    final preciseX = _numberToDouble(payload['preciseX']) ?? x;
    final preciseY = _numberToDouble(payload['preciseY']) ?? y;
    final estimatedProperties = _numberToInt(payload['estimatedProperties']);
    var sourceFlags =
        _sourceFlagsFromPayload(payload['sourceFlags']) ??
        fallbackSourceFlags ??
        StylusPoseSourceFlags.real;
    if (estimatedProperties != null && estimatedProperties != 0) {
      sourceFlags |= StylusPoseSourceFlags.estimated;
    }

    return ApplePencilTelemetrySample(
      position: Offset(x, y),
      precisePosition: Offset(preciseX, preciseY),
      timestamp: _numberToDouble(payload['timestamp']),
      pressure: _numberToDouble(payload['pressure']),
      force: _numberToDouble(payload['force']),
      maximumPossibleForce: _numberToDouble(payload['maximumPossibleForce']),
      altitudeAngle: _numberToDouble(payload['altitudeAngle']),
      azimuthAngle: _numberToDouble(payload['azimuthAngle']),
      azimuthUnitX: _numberToDouble(payload['azimuthUnitX']),
      azimuthUnitY: _numberToDouble(payload['azimuthUnitY']),
      rollAngle: _numberToDouble(payload['rollAngle']),
      majorRadius: _numberToDouble(payload['majorRadius']),
      majorRadiusTolerance: _numberToDouble(payload['majorRadiusTolerance']),
      estimatedProperties: estimatedProperties,
      estimatedPropertiesExpectingUpdates: _numberToInt(
        payload['estimatedPropertiesExpectingUpdates'],
      ),
      sourceFlags: sourceFlags,
    );
  }
}

/// A native Apple Pencil touch event emitted by the iOS telemetry bridge.
class ApplePencilTelemetryEvent {
  /// Creates a native Apple Pencil telemetry event.
  const ApplePencilTelemetryEvent({
    required this.phase,
    required this.sample,
    this.coalescedSamples = const [],
    this.predictedSamples = const [],
  });

  /// The lifecycle phase of the native touch.
  final ApplePencilInteractionPhase phase;

  /// The primary touch sample for this event.
  final ApplePencilTelemetrySample sample;

  /// Coalesced real samples supplied by UIKit.
  final List<ApplePencilTelemetrySample> coalescedSamples;

  /// Predicted samples supplied by UIKit.
  final List<ApplePencilTelemetrySample> predictedSamples;

  /// Whether this event should update the active writing sample.
  bool get isActive =>
      phase == ApplePencilInteractionPhase.began ||
      phase == ApplePencilInteractionPhase.changed;

  /// Real samples suitable for persisted stroke points.
  Iterable<ApplePencilTelemetrySample> get realSamples =>
      coalescedSamples.isEmpty ? [sample] : coalescedSamples;

  /// Parses a telemetry payload emitted by the iOS EventChannel.
  static ApplePencilTelemetryEvent? fromPayload(Object? payload) {
    if (payload is! Map) return null;

    final phase = ApplePencilInteractionPhase.fromName(
      payload['phase'] is String ? payload['phase'] as String : null,
    );
    if (phase == null) return null;

    final sample = ApplePencilTelemetrySample.fromPayload(payload);
    if (sample == null) return null;

    return ApplePencilTelemetryEvent(
      phase: phase,
      sample: sample,
      coalescedSamples: _parseSampleList(
        payload['coalesced'],
        fallbackSourceFlags: StylusPoseSourceFlags.coalesced,
      ),
      predictedSamples: _parseSampleList(
        payload['predicted'],
        fallbackSourceFlags: StylusPoseSourceFlags.predicted,
      ),
    );
  }

  static List<ApplePencilTelemetrySample> _parseSampleList(
    Object? payload, {
    required int fallbackSourceFlags,
  }) {
    if (payload is! List) return const [];

    return payload
        .map(
          (sample) => ApplePencilTelemetrySample.fromPayload(
            sample,
            fallbackSourceFlags: fallbackSourceFlags,
          ),
        )
        .whereType<ApplePencilTelemetrySample>()
        .toList(growable: false);
  }
}

double? _numberToDouble(Object? value) =>
    value is num ? value.toDouble() : null;

int? _numberToInt(Object? value) => value is num ? value.toInt() : null;

int? _sourceFlagsFromPayload(Object? value) {
  if (value is num) return value.toInt();
  return switch (value) {
    'real' => StylusPoseSourceFlags.real,
    'coalesced' => StylusPoseSourceFlags.coalesced,
    'predicted' => StylusPoseSourceFlags.predicted,
    _ => null,
  };
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

/// Provides native Apple Pencil touch telemetry events.
abstract class ApplePencilTelemetryService {
  /// The stream of native Apple Pencil telemetry events.
  Stream<ApplePencilTelemetryEvent> get events;
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

/// Apple Pencil telemetry service backed by an iOS EventChannel.
class EventChannelApplePencilTelemetryService
    implements ApplePencilTelemetryService {
  /// Creates an EventChannel-backed Apple Pencil telemetry service.
  const EventChannelApplePencilTelemetryService();

  static final _log = Logger('ApplePencilTelemetry');
  static const _eventChannel = EventChannel(
    'saber/apple_pencil_telemetry/events',
  );

  @override
  Stream<ApplePencilTelemetryEvent> get events {
    if (!Platform.isIOS) return const Stream.empty();

    return _eventChannel.receiveBroadcastStream().transform(
      StreamTransformer<dynamic, ApplePencilTelemetryEvent>.fromHandlers(
        handleData: (payload, sink) {
          final event = ApplePencilTelemetryEvent.fromPayload(payload);
          if (event == null) {
            _log.warning('Invalid Apple Pencil telemetry payload: $payload');
            return;
          }
          sink.add(event);
        },
        handleError: (error, stackTrace, sink) {
          _log.warning(
            'Apple Pencil telemetry stream failed',
            error,
            stackTrace,
          );
        },
      ),
    );
  }
}
