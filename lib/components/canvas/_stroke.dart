// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/data/extensions/point_extensions.dart';
import 'package:saber/data/tools/stylus_pose.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

class Stroke {
  static final log = Logger('Stroke');

  @visibleForTesting
  @protected
  final List<PointVector> points = [];

  /// Stylus pose samples aligned by index with [points].
  @visibleForTesting
  final List<StylusPose?> stylusPoses = [];

  bool get isEmpty => points.isEmpty;
  int get length => points.length;

  int pageIndex;
  HasSize page;
  final ToolId toolId;

  static const defaultColor = Colors.black;
  static const defaultPressureEnabled = true;

  Color color;
  bool pressureEnabled;
  final double rollSensitivity;
  final StrokeOptions options;

  List<Offset>? _lowQualityPolygon, _highQualityPolygon;
  List<Offset> get lowQualityPolygon =>
      _lowQualityPolygon ??= getPolygon(quality: .low);
  List<Offset> get highQualityPolygon =>
      _highQualityPolygon ??= getPolygon(quality: .high);

  Path? _lowQualityPath, _highQualityPath;
  Path get lowQualityPath =>
      _lowQualityPath ??= getPath(lowQualityPolygon, smooth: false);
  Path get highQualityPath => _highQualityPath ??= getPath(highQualityPolygon);

  void shift(Offset offset) {
    if (offset == .zero) return;

    points.shift(offset);
    _lowQualityPolygon?.shift(offset);
    _highQualityPolygon?.shift(offset);
    _lowQualityPath = _lowQualityPath?.shift(offset);
    _highQualityPath = _highQualityPath?.shift(offset);
  }

  void markPolygonNeedsUpdating() {
    _lowQualityPolygon = null;
    _highQualityPolygon = null;
    _lowQualityPath = null;
    _highQualityPath = null;
  }

  Stroke({
    required this.color,
    required this.pressureEnabled,
    required this.options,
    required this.pageIndex,
    required this.page,
    required this.toolId,
    this.rollSensitivity = 1,
  });

  factory Stroke.fromJson(
    Map<String, dynamic> json, {
    required int fileVersion,
    required int pageIndex,
    required HasSize page,
  }) {
    assert(json['i'] == pageIndex || json['i'] == null);
    switch (json['shape'] as String?) {
      case null:
        break;
      case 'circle':
        return CircleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      case 'rect':
        return RectangleStroke.fromJson(
          json,
          fileVersion: fileVersion,
          pageIndex: pageIndex,
          page: page,
        );
      default:
        log.severe('Unknown shape: ${json['shape']}');
    }

    final ToolId toolId = .parsePenType(json['ty'], fallback: .fountainPen);

    final options = StrokeOptions.fromJson(json);
    final pressureEnabled = json['pe'] ?? defaultPressureEnabled;
    if (toolId == .shapePen) {
      // Set smoothing and streamline to 0 for ShapePen
      // to mitigate https://github.com/saber-notes/saber/issues/1587
      options.smoothing = 0;
      options.streamline = 0;
    }

    final Color color;
    switch (json['c']) {
      case (final int value):
        color = Color(value);
      case (final Int64 value):
        color = Color(value.toInt());
      case null:
        color = defaultColor;
      default:
        throw Exception(
          'Invalid color value: (${json['c'].runtimeType}) ${json['c']}',
        );
    }

    final offset = Offset(json['ox'] ?? 0, json['oy'] ?? 0);
    final pointsJson = json['p'] as List<dynamic>;
    final Iterable<PointVector> points;
    if (fileVersion >= 13) {
      points = pointsJson.map(
        (point) => PointExtensions.fromBsonBinary(json: point, offset: offset),
      );
    } else {
      points = pointsJson.map(
        // ignore: deprecated_member_use_from_same_package
        (point) => PointExtensions.fromJson(
          json: Map<String, dynamic>.from(point),
          offset: offset,
        ),
      );
    }

    final stroke = Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options,
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
      rollSensitivity: (json['rs'] as num?)?.toDouble() ?? 1,
    )..points.addAll(points);
    stroke._addStylusPosesFromJson(json['ap'], fileVersion: fileVersion);
    return stroke;
  }
  Map<String, dynamic> toJson() {
    final pointsJson = <Object>[];
    final posesJson = <Object?>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (!point.isFinite) continue;

      pointsJson.add(point.toBsonBinary());
      posesJson.add(stylusPoses.getOrNull(i)?.toBsonBinary());
    }

    final hasStylusPoses = posesJson.any((pose) => pose != null);

    // these json keys should not be the same as the ones in [StrokeOptions.toJson]
    final json = {
      'shape': null,
      'p': pointsJson,
      'i': pageIndex,
      'ty': toolId.id,
      'pe': pressureEnabled,
      'c': color.toARGB32(),
      if (rollSensitivity != 1) 'rs': rollSensitivity,
    }..addAll(options.toJson());

    if (hasStylusPoses) json['ap'] = posesJson;
    return json;
  }

  void addPoint(Offset point, [double? pressure, StylusPose? stylusPose]) {
    if (!pressureEnabled) {
      pressure = null;
    } else if (pressure != null) {
      options.simulatePressure = false;
    }

    points.add(PointVector(point.dx, point.dy, pressure));
    stylusPoses.add(stylusPose);
    markPolygonNeedsUpdating();
  }

  void addPoints(List<Offset> points) {
    for (final point in points) {
      addPoint(point);
    }
  }

  void popFirstPoint() {
    points.removeAt(0);
    if (stylusPoses.isNotEmpty) stylusPoses.removeAt(0);
    markPolygonNeedsUpdating();
  }

  void _addStylusPosesFromJson(Object? posesJson, {required int fileVersion}) {
    if (fileVersion < 20 || posesJson is! List) return;

    stylusPoses
      ..clear()
      ..addAll(
        posesJson
            .take(points.length)
            .map(StylusPose.fromJson)
            .cast<StylusPose?>(),
      );

    while (stylusPoses.length < points.length) {
      stylusPoses.add(null);
    }
  }

  void _removePointAt(int index) {
    points.removeAt(index);
    if (index < stylusPoses.length) stylusPoses.removeAt(index);
  }

  /// Points that are closer than this
  /// threshold multiplied by the stroke's size
  /// will be counted as duplicates.
  static const _optimisePointsThreshold = 0.1;

  /// Removes points that are too close together. See [_optimisePointsThreshold].
  ///
  /// This function is idempotent, so running it multiple times
  /// will not change the result.
  ///
  /// This function does not change [_polygonNeedsUpdating].
  void optimisePoints({double thresholdMultiplier = _optimisePointsThreshold}) {
    if (points.length <= 3) return;

    final minDistance = options.size * thresholdMultiplier;

    // Remove points with null pressure because they were duplicates
    for (int i = points.length - 1; i >= 0; i--) {
      if (points[i].pressure == null) _removePointAt(i);
    }

    for (int i = 1; i < points.length - 1; i++) {
      final point = points[i];
      final prev = points[i - 1];
      final next = points[i + 1];

      if (prev.distanceSquaredTo(point) < minDistance * minDistance &&
          point.distanceSquaredTo(next) < minDistance * minDistance) {
        _removePointAt(i);
        i--;
      }
    }
  }

  @protected
  List<Offset> getPolygon({required StrokeQuality quality}) {
    final pointIndices = skipPointIndices(points, quality.N);
    final selectedPoints = pointIndices.map((index) => points[index]).toList();

    if (!pressureEnabled) {
      options.simulatePressure = false;
    }
    final rememberSimulatedPressure =
        quality == .high && options.simulatePressure && options.isComplete;

    final polygon = getStroke(
      selectedPoints,
      options: switch (quality) {
        .low => options.copyWith(
          simulatePressure: false,
          smoothing: 0,
          streamline: 0,
        ),
        .high => options,
      },
      rememberSimulatedPressure: rememberSimulatedPressure,
    );

    if (rememberSimulatedPressure) {
      // Ensure we don't simulate pressure again
      options.simulatePressure = false;
      // Remove points that are too close together
      optimisePoints();
    }

    return polygon;
  }

  bool get _hasRollPose => stylusPoses.any((pose) => pose?.rollAngle != null);

  /// Average Apple Pencil Pro roll for whole-stroke effects.
  double? get averageRollAngle => StylusPose.averageCanvasRoll(stylusPoses);

  static double _tangentAngleAt(List<PointVector> points, int index) {
    final previous = points[index == 0 ? index : index - 1];
    final next = points[index == points.length - 1 ? index : index + 1];
    final delta = next - previous;
    if (delta == Offset.zero) return 0;
    return atan2(delta.dy, delta.dx) + pi / 2;
  }

  /// Returns a [Path] that represents the stroke.
  ///
  /// If [smooth] is true, and the stroke is complete,
  /// the path will be a smooth curve between the points in [polygon].
  ///
  /// Otherwise, the path will use straight lines between each point
  /// in [polygon] for performance.
  @protected
  Path getPath(List<Offset> polygon, {bool smooth = true}) {
    if (toolId == ToolId.fountainPen && _hasRollPose) {
      return _getCalligraphyPath();
    }

    if (smooth && options.isComplete) {
      return smoothPathFromPolygon(polygon);
    }

    return Path()..addPolygon(polygon, true);
  }

  Path _getCalligraphyPath() {
    if (points.length < 2) {
      return Path()..addPolygon(highQualityPolygon, true);
    }

    final path = Path()..fillType = PathFillType.nonZero;
    final nibs = [for (var i = 0; i < points.length; i++) _nibAt(i)];

    _addNibFootprint(path, points.first, nibs.first);

    for (var i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      if (start == end) continue;

      final delta = end - start;
      final length = delta.distance;
      if (length == 0) continue;

      final normal = Offset(-delta.dy / length, delta.dx / length);
      final startHalfWidth = nibs[i - 1].supportRadiusAlong(normal);
      final endHalfWidth = nibs[i].supportRadiusAlong(normal);
      _addConsistentPolygon(path, [
        start + normal * startHalfWidth,
        end + normal * endHalfWidth,
        end - normal * endHalfWidth,
        start - normal * startHalfWidth,
      ]);
      _addNibFootprint(path, end, nibs[i]);
    }

    if (path.getBounds().isEmpty) {
      return Path()..addPolygon(highQualityPolygon, true);
    }

    return path;
  }

  static void _addConsistentPolygon(Path path, List<Offset> polygon) {
    if (_signedPolygonArea(polygon) < 0) {
      path.addPolygon(polygon.reversed.toList(), true);
      return;
    }

    path.addPolygon(polygon, true);
  }

  static double _signedPolygonArea(List<Offset> polygon) {
    var area = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      area += current.dx * next.dy - next.dx * current.dy;
    }
    return area / 2;
  }

  static void _addNibFootprint(Path path, Offset center, _CalligraphyNib nib) {
    const pointCount = 12;
    _addConsistentPolygon(path, [
      for (var i = 0; i < pointCount; i++)
        center +
            nib.major * cos(2 * pi * i / pointCount) +
            nib.minor * sin(2 * pi * i / pointCount),
    ]);
  }

  _CalligraphyNib _nibAt(int index) {
    final point = points[index];
    final pose = stylusPoses.getOrNull(index);
    final pressure = point.pressure ?? pose?.pressure ?? 0.5;
    final majorRadius = options.size * (0.18 + pressure.clamp(0.0, 1.0) * 0.45);
    final minorRadius = max(options.size * 0.12, majorRadius * 0.4);
    final tangentAngle = _tangentAngleAt(points, index);
    final rollAngle = StylusPose.canvasAngleFromNativeRoll(pose?.rollAngle);
    final angle = rollAngle == null
        ? tangentAngle
        : _lerpAngle(tangentAngle, rollAngle, rollSensitivity.clamp(0.0, 1.0));
    final direction = Offset(cos(angle), sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    return _CalligraphyNib(
      major: direction * majorRadius,
      minor: normal * minorRadius,
    );
  }

  static double _lerpAngle(double from, double to, double t) {
    final delta = atan2(sin(to - from), cos(to - from));
    return from + delta * t;
  }

  /// Returns a list with every Nth point in [points].
  static List<PointVector> skipPoints(List<PointVector> points, int N) {
    return skipPointIndices(points, N).map((index) => points[index]).toList();
  }

  /// Returns the indices for every Nth point in [points].
  static List<int> skipPointIndices(List<PointVector> points, int N) {
    if (points.isEmpty) return const [];

    // Nothing is being skipped, just return [points].
    if (N <= 1) return [for (var i = 0; i < points.length; i++) i];

    // If we have too few points, skip less points
    final divided = points.length / N;
    const minDivided = 8;
    if (divided < minDivided) {
      N = (N * divided / minDivided).floor();
      if (N <= 1) return [for (var i = 0; i < points.length; i++) i];
    }

    return [
      for (int i = 0; i < points.length - 1; i += N) i,
      points.length - 1,
    ];
  }

  static Path smoothPathFromPolygon(List<Offset> polygon) {
    final path = Path();
    path.moveTo(polygon.first.dx, polygon.first.dy);
    for (int i = 1; i < polygon.length - 1; i++) {
      final p1 = polygon[i];
      final p2 = polygon[i + 1];
      final mid = (p1 + p2) / 2;
      path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  String toSvgPath() {
    String toSvgPoint(Offset point) {
      return '${point.dx} '
          '${page.size.height - point.dy}';
    }

    // Remove NaN points, and convert to SVG coordinates
    final svgPoints = highQualityPolygon
        .where((offset) => offset.isFinite)
        .map(toSvgPoint);

    return svgPoints.isNotEmpty ? 'M${svgPoints.join('L')}' : '';
  }

  double get maxY {
    return points.isEmpty ? 0 : points.map((point) => point.y).reduce(max);
  }

  RecognizedUnistroke? detectShape() {
    if (points.length < 3) return null;
    return recognizeUnistroke(points);
  }

  /// Uses the one_dollar_unistroke_recognizer package
  /// only to recognize straight lines.
  ///
  /// In addition, the line must be sufficiently long
  /// relative to [options.size].
  bool isStraightLine([int minLength = 5]) {
    if (points.length < 3) return false;

    final recognized = recognizeUnistroke(
      points,
      overrideReferenceUnistrokes: default$1Unistrokes
          .where((unistroke) => unistroke.name == DefaultUnistrokeNames.line)
          .toList(),
    );
    if (recognized == null) return false;
    assert(recognized.name == DefaultUnistrokeNames.line);
    if (recognized.score < 0.7) return false;

    final sqrLength = points.first.distanceSquaredTo(points.last);
    final sqrMinLength = minLength * minLength * options.size * options.size;
    return sqrLength >= sqrMinLength;
  }

  /// Replaces the points in this stroke with a straight line.
  ///
  /// If the resulting line is close to horizontal or vertical,
  /// it will be snapped to be exactly horizontal or vertical.
  void convertToLine() {
    assert(points.length >= 2);

    final firstPose = stylusPoses.getOrNull(0);
    final lastPose = stylusPoses.getOrNull(points.length - 1);

    // Use the average pressure
    final pressure = points.map((point) => point.pressure ?? 0.5).average;
    var firstPoint = PointVector.fromOffset(
      offset: points.first,
      pressure: pressure,
    );
    var lastPoint = PointVector.fromOffset(
      offset: points.last,
      pressure: pressure,
    );

    // Snap to the horizontal or vertical axis
    (firstPoint, lastPoint) = snapLine(firstPoint, lastPoint);

    points.clear();
    points.add(firstPoint);
    points.add(lastPoint);
    points.add(lastPoint);
    stylusPoses
      ..clear()
      ..add(firstPose)
      ..add(lastPose)
      ..add(lastPose);
    options.isComplete = true;
    options.start.taperEnabled = false;
    options.end.taperEnabled = false;
    markPolygonNeedsUpdating();
  }

  /// Snaps a line to either horizontal or vertical
  /// if the angle is close enough.
  static (PointVector firstPoint, PointVector lastPoint) snapLine(
    PointVector firstPoint,
    PointVector lastPoint,
  ) {
    final dx = (lastPoint.dx - firstPoint.dx).abs();
    final dy = (lastPoint.dy - firstPoint.dy).abs();
    final angle = atan2(dy, dx);

    const snapAngle = 5 * pi / 180; // 5 degrees
    if (angle < snapAngle) {
      // snap to horizontal
      return (
        firstPoint,
        PointVector(lastPoint.dx, firstPoint.dy, lastPoint.pressure),
      );
    } else if (angle > pi / 2 - snapAngle) {
      // snap to vertical
      return (
        firstPoint,
        PointVector(firstPoint.dx, lastPoint.dy, lastPoint.pressure),
      );
    } else {
      return (firstPoint, lastPoint);
    }
  }

  Stroke copy() =>
      Stroke(
          color: color,
          pressureEnabled: pressureEnabled,
          options: options.copyWith(),
          pageIndex: pageIndex,
          page: page,
          toolId: toolId,
          rollSensitivity: rollSensitivity,
        )
        ..points.addAll(points)
        ..stylusPoses.addAll(stylusPoses);
}

enum StrokeQuality {
  low(4),
  high(1);

  const StrokeQuality(this.N);

  /// We use every Nth point for this quality level.
  final int N;
}

class _CalligraphyNib {
  const _CalligraphyNib({required this.major, required this.minor});

  final Offset major;
  final Offset minor;

  double supportRadiusAlong(Offset direction) {
    final majorProjection = major.dx * direction.dx + major.dy * direction.dy;
    final minorProjection = minor.dx * direction.dx + minor.dy * direction.dy;
    return sqrt(
      majorProjection * majorProjection + minorProjection * minorProjection,
    );
  }
}
