/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bson/bson.dart';

/// Source bit flags for persisted stylus pose samples.
abstract final class StylusPoseSourceFlags {
  /// A delivered touch sample.
  static const real = 1;

  /// A coalesced touch sample supplied by UIKit.
  static const coalesced = 1 << 1;

  /// A predicted touch sample supplied by UIKit.
  static const predicted = 1 << 2;

  /// A sample containing estimated UIKit properties.
  static const estimated = 1 << 3;
}

/// Persisted Apple Pencil pose data aligned with a stroke point.
class StylusPose {
  /// Creates a persisted stylus pose sample.
  const StylusPose({
    this.timestampDelta,
    this.pressure,
    this.altitudeAngle,
    this.azimuthAngle,
    this.azimuthUnitX,
    this.azimuthUnitY,
    this.rollAngle,
    this.sourceFlags = StylusPoseSourceFlags.real,
  });

  /// Time from the beginning of the stroke.
  final double? timestampDelta;

  /// Normalized native pressure.
  final double? pressure;

  /// Apple Pencil altitude angle in radians.
  final double? altitudeAngle;

  /// Apple Pencil azimuth angle in radians.
  final double? azimuthAngle;

  /// X component of the azimuth unit vector.
  final double? azimuthUnitX;

  /// Y component of the azimuth unit vector.
  final double? azimuthUnitY;

  /// Apple Pencil Pro roll angle in radians.
  final double? rollAngle;

  /// Bitset describing whether the sample is real/coalesced/predicted/estimated.
  final int sourceFlags;

  /// Whether the sample carries any pose field worth persisting.
  bool get hasTelemetry =>
      timestampDelta != null ||
      pressure != null ||
      altitudeAngle != null ||
      azimuthAngle != null ||
      azimuthUnitX != null ||
      azimuthUnitY != null ||
      rollAngle != null;

  /// Whether this sample came from UIKit prediction rather than delivered input.
  bool get isPredicted => sourceFlags & StylusPoseSourceFlags.predicted != 0;

  /// Creates a copy with selected fields replaced.
  StylusPose copyWith({
    double? timestampDelta,
    double? pressure,
    double? altitudeAngle,
    double? azimuthAngle,
    double? azimuthUnitX,
    double? azimuthUnitY,
    double? rollAngle,
    int? sourceFlags,
  }) => StylusPose(
    timestampDelta: timestampDelta ?? this.timestampDelta,
    pressure: pressure ?? this.pressure,
    altitudeAngle: altitudeAngle ?? this.altitudeAngle,
    azimuthAngle: azimuthAngle ?? this.azimuthAngle,
    azimuthUnitX: azimuthUnitX ?? this.azimuthUnitX,
    azimuthUnitY: azimuthUnitY ?? this.azimuthUnitY,
    rollAngle: rollAngle ?? this.rollAngle,
    sourceFlags: sourceFlags ?? this.sourceFlags,
  );

  /// Decodes a pose sample from a compact BSON binary float array.
  static StylusPose? fromJson(Object? json) {
    if (json == null) return null;
    if (json is! BsonBinary) return null;

    final values = json.byteList.buffer.asFloat32List();
    if (values.length < 8) return null;

    return StylusPose(
      timestampDelta: _nanToNull(values[0]),
      pressure: _nanToNull(values[1]),
      altitudeAngle: _nanToNull(values[2]),
      azimuthAngle: _nanToNull(values[3]),
      azimuthUnitX: _nanToNull(values[4]),
      azimuthUnitY: _nanToNull(values[5]),
      rollAngle: _nanToNull(values[6]),
      sourceFlags: values[7].round(),
    );
  }

  /// Encodes this pose sample as a compact BSON binary float array.
  BsonBinary toBsonBinary() {
    final values = Float32List.fromList([
      timestampDelta ?? double.nan,
      pressure ?? double.nan,
      altitudeAngle ?? double.nan,
      azimuthAngle ?? double.nan,
      azimuthUnitX ?? double.nan,
      azimuthUnitY ?? double.nan,
      rollAngle ?? double.nan,
      sourceFlags.toDouble(),
    ]);
    return BsonBinary.from(values.buffer.asUint8List());
  }

  static double? _nanToNull(double value) => value.isNaN ? null : value;

  /// Returns the average roll angle, accounting for angle wraparound.
  static double? averageRoll(Iterable<StylusPose?> poses) {
    var sinSum = 0.0;
    var cosSum = 0.0;
    var count = 0;

    for (final pose in poses) {
      final roll = pose?.rollAngle;
      if (roll == null) continue;

      sinSum += math.sin(roll);
      cosSum += math.cos(roll);
      count++;
    }

    if (count == 0) return null;
    return math.atan2(sinSum / count, cosSum / count);
  }

  /// Converts UIKit's native roll angle into Saber's canvas angle.
  ///
  /// UIKit reports roll in the native view coordinate convention. Saber uses
  /// Flutter canvas angles with a mirrored visual rotation for Apple Pencil Pro
  /// nib effects, so roll-driven rendering should use this normalized angle.
  static double? canvasAngleFromNativeRoll(double? rollAngle) =>
      rollAngle == null ? null : -rollAngle;

  /// Returns the average roll angle normalized for canvas rendering.
  static double? averageCanvasRoll(Iterable<StylusPose?> poses) =>
      canvasAngleFromNativeRoll(averageRoll(poses));
}
