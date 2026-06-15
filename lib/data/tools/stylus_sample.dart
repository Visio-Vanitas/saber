/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/gestures.dart';
import 'package:saber/data/tools/stylus_pose.dart';

/// A structured sample of the current pointer or stylus state.
class StylusSample {
  /// Creates a stylus sample.
  const StylusSample({
    required this.kind,
    this.pressure,
    this.tilt,
    this.orientation,
    this.timestamp,
    this.altitudeAngle,
    this.azimuthAngle,
    this.azimuthUnitX,
    this.azimuthUnitY,
    this.rollAngle,
    this.sourceFlags = StylusPoseSourceFlags.real,
  });

  /// The pointer device kind that produced this sample.
  final PointerDeviceKind kind;

  /// Normalized pressure in the range 0 to 1, when available.
  final double? pressure;

  /// Stylus tilt in radians, when available.
  final double? tilt;

  /// Stylus orientation or side-roll angle in radians, when available.
  final double? orientation;

  /// Native event timestamp, when available.
  final double? timestamp;

  /// Native Apple Pencil altitude angle in radians, when available.
  final double? altitudeAngle;

  /// Native Apple Pencil azimuth angle in radians, when available.
  final double? azimuthAngle;

  /// Native Apple Pencil azimuth unit vector x component, when available.
  final double? azimuthUnitX;

  /// Native Apple Pencil azimuth unit vector y component, when available.
  final double? azimuthUnitY;

  /// Native Apple Pencil Pro roll angle in radians, when available.
  final double? rollAngle;

  /// Bit flags describing the source of the native sample.
  final int sourceFlags;

  /// Whether this sample came from a stylus-like pointer.
  bool get isStylus =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  /// Creates a sample from a Flutter pointer event.
  static StylusSample fromPointerEvent(PointerEvent event) {
    final isStylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    if (!isStylus) return StylusSample(kind: event.kind);

    return StylusSample(
      kind: event.kind,
      pressure: _normalizedPressure(event),
      tilt: event.tilt,
      orientation: event.orientation,
      azimuthAngle: event.orientation,
    );
  }

  /// Converts this input sample into a persisted pose sample.
  StylusPose? toPose({double? strokeStartTimestamp}) {
    if (!isStylus) return null;

    final pose = StylusPose(
      timestampDelta: timestamp == null
          ? null
          : timestamp! - (strokeStartTimestamp ?? timestamp!),
      pressure: pressure,
      altitudeAngle: altitudeAngle,
      azimuthAngle: azimuthAngle ?? orientation,
      azimuthUnitX: azimuthUnitX,
      azimuthUnitY: azimuthUnitY,
      rollAngle: rollAngle,
      sourceFlags: sourceFlags,
    );

    return pose.hasTelemetry ? pose : null;
  }

  static double? _normalizedPressure(PointerEvent event) {
    if (event.pressureMin == event.pressureMax) return null;

    final value =
        (event.pressure - event.pressureMin) /
        (event.pressureMax - event.pressureMin);
    return value.clamp(0.0, 1.0).toDouble();
  }
}
