/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/gestures.dart';

/// A real-time diagnostic snapshot for external pointer and stylus data.
class PeripheralDebugData {
  /// Creates a diagnostic snapshot for external pointer and stylus data.
  const PeripheralDebugData({
    required this.source,
    required this.updatedAt,
    required this.active,
    this.kind,
    this.pageIndex,
    this.globalPosition,
    this.pagePosition,
    this.rawPressure,
    this.effectivePressure,
    this.force,
    this.maximumPossibleForce,
    this.hoverDistance,
    this.hoverDistanceMax,
    this.tilt,
    this.orientation,
    this.altitudeAngle,
    this.azimuthAngle,
    this.rollAngle,
    this.majorRadius,
    this.timestamp,
    this.sourceFlags,
    this.coalescedCount,
    this.predictedCount,
  });

  /// The input path that produced this data.
  final String source;

  /// When this snapshot was produced.
  final DateTime updatedAt;

  /// Whether the external pointer is actively hovering or writing.
  final bool active;

  /// The Flutter pointer kind.
  final PointerDeviceKind? kind;

  /// Zero-based Saber page index under the pointer.
  final int? pageIndex;

  /// Pointer position in Flutter view coordinates.
  final Offset? globalPosition;

  /// Pointer position in page-local coordinates.
  final Offset? pagePosition;

  /// Raw normalized pressure before Saber applies the pressure curve.
  final double? rawPressure;

  /// Effective normalized pressure after Saber applies the pressure curve.
  final double? effectivePressure;

  /// Native force value when UIKit reports it.
  final double? force;

  /// Native maximum force value when UIKit reports it.
  final double? maximumPossibleForce;

  /// Hover distance value when available.
  final double? hoverDistance;

  /// Maximum hover distance value when available.
  final double? hoverDistanceMax;

  /// Flutter stylus tilt in radians.
  final double? tilt;

  /// Flutter stylus orientation in radians.
  final double? orientation;

  /// Native Apple Pencil altitude angle in radians.
  final double? altitudeAngle;

  /// Native Apple Pencil azimuth angle in radians.
  final double? azimuthAngle;

  /// Native Apple Pencil Pro roll angle in radians.
  final double? rollAngle;

  /// Native touch major radius when UIKit reports it.
  final double? majorRadius;

  /// Native event timestamp.
  final double? timestamp;

  /// Stylus pose source flags.
  final int? sourceFlags;

  /// Number of coalesced samples in the latest native event.
  final int? coalescedCount;

  /// Number of predicted samples in the latest native event.
  final int? predictedCount;
}
