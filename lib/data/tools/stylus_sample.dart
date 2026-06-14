/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/gestures.dart';

/// A structured sample of the current pointer or stylus state.
class StylusSample {
  /// Creates a stylus sample.
  const StylusSample({
    required this.kind,
    this.pressure,
    this.tilt,
    this.orientation,
  });

  /// The pointer device kind that produced this sample.
  final PointerDeviceKind kind;

  /// Normalized pressure in the range 0 to 1, when available.
  final double? pressure;

  /// Stylus tilt in radians, when available.
  final double? tilt;

  /// Stylus orientation or side-roll angle in radians, when available.
  final double? orientation;

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
    );
  }

  static double? _normalizedPressure(PointerEvent event) {
    if (event.pressureMin == event.pressureMax) return null;

    final value =
        (event.pressure - event.pressureMin) /
        (event.pressureMax - event.pressureMin);
    return value.clamp(0.0, 1.0).toDouble();
  }

}
