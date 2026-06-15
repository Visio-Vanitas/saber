/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:math' as math;

/// A normalized pressure control point.
class PressureCurvePoint {
  /// Creates a normalized pressure control point.
  const PressureCurvePoint({required this.input, required this.output});

  /// Raw stylus pressure, from 0 to 1.
  final double input;

  /// Effective pressure used for rendering, from 0 to 1.
  final double output;

  /// Parses a pressure control point from JSON.
  factory PressureCurvePoint.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    return PressureCurvePoint(
      input: (map['x'] as num).toDouble(),
      output: (map['y'] as num).toDouble(),
    );
  }

  /// Converts this pressure control point to JSON.
  Map<String, double> toJson() => {'x': input, 'y': output};
}

/// A monotone smooth mapping from raw stylus pressure to effective pressure.
class PressureCurve {
  /// Creates a pressure curve from normalized control points.
  PressureCurve(Iterable<PressureCurvePoint> points)
    : points = sanitizePoints(points);

  /// A neutral 0% to 100% pressure mapping.
  PressureCurve.neutral()
    : points = const [
        PressureCurvePoint(input: 0, output: 0),
        PressureCurvePoint(input: 1, output: 1),
      ];

  /// Ordered normalized control points.
  final List<PressureCurvePoint> points;

  /// Parses a pressure curve from JSON, including legacy single-value curves.
  factory PressureCurve.fromJson(Object json) {
    if (json is num) return PressureCurve.fromLegacyCurve(json.toDouble());

    if (json is List) {
      return PressureCurve(
        json.map((point) => PressureCurvePoint.fromJson(point)),
      );
    }

    final map = json as Map<String, dynamic>;
    final points = map['points'];
    if (points is! List) return PressureCurve.neutral();
    return PressureCurve(
      points.map((point) => PressureCurvePoint.fromJson(point)),
    );
  }

  /// Builds a multi-point curve that approximates the old single slider value.
  factory PressureCurve.fromLegacyCurve(double curve) {
    final normalizedCurve = curve.clamp(-1.0, 1.0).toDouble();
    if (normalizedCurve == 0) return PressureCurve.neutral();

    final gamma = normalizedCurve > 0
        ? 1 / (1 + normalizedCurve * 1.75)
        : 1 + -normalizedCurve * 1.75;
    return PressureCurve(
      const [0.0, 0.25, 0.5, 0.75, 1.0].map(
        (input) => PressureCurvePoint(
          input: input,
          output: math.pow(input, gamma).clamp(0.0, 1.0).toDouble(),
        ),
      ),
    );
  }

  /// Converts this pressure curve to JSON.
  Map<String, Object> toJson() => {
    'points': points.map((point) => point.toJson()).toList(),
  };

  /// Applies this curve to a raw pressure value.
  double apply(double pressure) {
    final input = pressure.clamp(0.0, 1.0).toDouble();
    final orderedPoints = points;
    if (orderedPoints.length == 2) {
      final start = orderedPoints.first;
      final end = orderedPoints.last;
      final span = end.input - start.input;
      if (span <= 0) return end.output;
      final t = (input - start.input) / span;
      return (start.output + (end.output - start.output) * t)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    for (var i = 1; i < orderedPoints.length; i++) {
      final next = orderedPoints[i];
      if (input > next.input) continue;

      return _interpolateMonotoneHermite(
        input: input,
        segmentIndex: i - 1,
        tangents: _monotoneTangents(orderedPoints),
      );
    }

    return orderedPoints.last.output.clamp(0.0, 1.0).toDouble();
  }

  /// Returns true when [pressure] falls within a zero-output curve segment.
  bool isDeadZone(double pressure) {
    final input = pressure.clamp(0.0, 1.0).toDouble();

    for (var i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      if (input < start.input || input > end.input) continue;
      return start.output == 0 && end.output == 0;
    }

    return false;
  }

  /// Returns a copy with sanitized control points.
  PressureCurve copyWithPoints(Iterable<PressureCurvePoint> points) {
    return PressureCurve(points);
  }

  /// Clamps, sorts, de-duplicates, and ensures a non-decreasing curve.
  static List<PressureCurvePoint> sanitizePoints(
    Iterable<PressureCurvePoint> points,
  ) {
    final sorted =
        points
            .map(
              (point) => PressureCurvePoint(
                input: point.input.clamp(0.0, 1.0).toDouble(),
                output: point.output.clamp(0.0, 1.0).toDouble(),
              ),
            )
            .toList()
          ..sort((a, b) => a.input.compareTo(b.input));

    final deduped = <PressureCurvePoint>[];
    for (final point in sorted) {
      if (deduped.isNotEmpty &&
          (deduped.last.input - point.input).abs() < 0.001) {
        deduped[deduped.length - 1] = point;
      } else {
        deduped.add(point);
      }
    }

    if (deduped.isEmpty || deduped.first.input > 0) {
      deduped.insert(0, const PressureCurvePoint(input: 0, output: 0));
    } else {
      deduped[0] = const PressureCurvePoint(input: 0, output: 0);
    }

    if (deduped.last.input < 1) {
      deduped.add(const PressureCurvePoint(input: 1, output: 1));
    } else {
      deduped[deduped.length - 1] = const PressureCurvePoint(
        input: 1,
        output: 1,
      );
    }

    var previousOutput = 0.0;
    for (var i = 1; i < deduped.length - 1; i++) {
      final point = deduped[i];
      final output = point.output.clamp(previousOutput, 1.0).toDouble();
      deduped[i] = PressureCurvePoint(input: point.input, output: output);
      previousOutput = output;
    }

    return List.unmodifiable(deduped);
  }

  static List<double> _monotoneTangents(List<PressureCurvePoint> points) {
    final segmentSlopes = <double>[];
    for (var i = 0; i < points.length - 1; i++) {
      final dx = points[i + 1].input - points[i].input;
      final dy = points[i + 1].output - points[i].output;
      segmentSlopes.add(dx <= 0 ? 0 : dy / dx);
    }

    final tangents = List<double>.filled(points.length, 0);
    tangents[0] = segmentSlopes.first;
    tangents[tangents.length - 1] = segmentSlopes.last;
    for (var i = 1; i < points.length - 1; i++) {
      tangents[i] = (segmentSlopes[i - 1] + segmentSlopes[i]) / 2;
    }

    for (var i = 0; i < segmentSlopes.length; i++) {
      final slope = segmentSlopes[i];
      if (slope == 0) {
        tangents[i] = 0;
        tangents[i + 1] = 0;
        continue;
      }

      final a = tangents[i] / slope;
      final b = tangents[i + 1] / slope;
      final magnitude = math.sqrt(a * a + b * b);
      if (magnitude <= 3) continue;

      final scale = 3 / magnitude;
      tangents[i] = scale * a * slope;
      tangents[i + 1] = scale * b * slope;
    }

    return tangents;
  }

  double _interpolateMonotoneHermite({
    required double input,
    required int segmentIndex,
    required List<double> tangents,
  }) {
    final start = points[segmentIndex];
    final end = points[segmentIndex + 1];
    final dx = end.input - start.input;
    if (dx <= 0) return end.output;

    final t = (input - start.input) / dx;
    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;

    return (h00 * start.output +
            h10 * dx * tangents[segmentIndex] +
            h01 * end.output +
            h11 * dx * tangents[segmentIndex + 1])
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
