/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/stylus_sample.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

class Pen extends Tool {
  @protected
  @visibleForTesting
  Pen({
    required this.name,
    required this.sizeMin,
    required this.sizeMax,
    required this.sizeStep,
    required this.icon,
    required this.options,
    required this.pressureEnabled,
    required this.pressureCurve,
    required this.tiltSensitivity,
    required this.rollSensitivity,
    required this.color,
    required this.toolId,
  });

  Pen.fountainPen()
    : name = t.editor.pens.fountainPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = fountainPenIcon,
      options = stows.lastFountainPenOptions.value,
      pressureEnabled = true,
      pressureCurve = stows.fountainPenPressureCurve,
      tiltSensitivity = 0,
      rollSensitivity = stows.lastFountainPenRollSensitivity.value,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen;

  Pen.ballpointPen()
    : name = t.editor.pens.ballpointPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = ballpointPenIcon,
      options = stows.lastBallpointPenOptions.value,
      pressureEnabled = false,
      pressureCurve = PressureCurve.neutral(),
      tiltSensitivity = 0,
      rollSensitivity = 0,
      color = Color(stows.lastBallpointPenColor.value),
      toolId = .ballpointPen;

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax = ((sizeMax - sizeMin) / sizeStep)
      .round();
  final Object icon;

  @override
  final ToolId toolId;

  static const fountainPenIcon = FontAwesomeIcons.penFancy;
  static const ballpointPenIcon = FontAwesomeIcons.pen;

  static Stroke? currentStroke;
  static EditorPage? _currentStrokePage;
  static int? _currentStrokePageIndex;
  static double? _currentStrokeStartTimestamp;

  /// Whether the pen advanced settings panel is currently open.
  static final advancedSettingsOpen = ValueNotifier(false);

  Color color;
  bool pressureEnabled;
  PressureCurve pressureCurve;
  double tiltSensitivity;
  double rollSensitivity;
  StrokeOptions options;

  static var _currentPen = Pen.fountainPen();
  static Pen get currentPen => _currentPen;
  static set currentPen(Pen currentPen) {
    assert(
      currentPen is! Highlighter,
      'Use Highlighter.currentHighlighter instead',
    );
    assert(currentPen is! Pencil, 'Use Pencil.currentPencil instead');
    _currentPen = currentPen;
  }

  void onDragStart(
    Offset position,
    EditorPage page,
    int pageIndex,
    StylusSample? stylusSample,
  ) {
    _currentStrokePage = page;
    _currentStrokePageIndex = pageIndex;
    currentStroke = _newStroke(page: page, pageIndex: pageIndex);
    _currentStrokeStartTimestamp = null;
    onDragUpdate(position, stylusSample);
  }

  Stroke? onDragUpdate(Offset position, StylusSample? stylusSample) {
    if (isPressureDeadZoneForSample(stylusSample)) {
      return _finishCurrentStrokeSegment();
    }

    currentStroke ??= _newStrokeFromCurrentPage();
    if (currentStroke == null) return null;

    _currentStrokeStartTimestamp ??= stylusSample?.timestamp;
    currentStroke?.addPoint(
      position,
      _effectivePressure(stylusSample),
      stylusSample?.toPose(strokeStartTimestamp: _currentStrokeStartTimestamp),
    );
    return null;
  }

  Stroke? onDragEnd() {
    final stroke = _finishCurrentStrokeSegment();
    currentStroke = null;
    _currentStrokePage = null;
    _currentStrokePageIndex = null;
    _currentStrokeStartTimestamp = null;
    if (stroke == null) return null;

    return stroke;
  }

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(size: 5);

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get shapePenOptions =>
      defaultOptions.copyWith(smoothing: 0, streamline: 0);
  static StrokeOptions get highlighterOptions =>
      defaultOptions.copyWith(size: 50);
  static StrokeOptions get pencilOptions => defaultOptions.copyWith(
    streamline: 0.1,
    start: StrokeEndOptions.start(taperEnabled: true, customTaper: 1),
    end: StrokeEndOptions.end(taperEnabled: true, customTaper: 1),
  );

  /// Maps raw stylus pressure to the effective pressure used by the stroke.
  static double? applyPressureCurve(double? pressure, PressureCurve curve) {
    if (pressure == null) return null;
    if (curve.isDeadZone(pressure)) return null;

    return curve.apply(pressure);
  }

  /// Returns the effective pressure after tilt and pressure-curve mapping.
  double? effectivePressureForSample(StylusSample? stylusSample) {
    return applyPressureCurve(
      pressureCurveInputForSample(stylusSample),
      pressureCurve,
    );
  }

  /// Returns true when this sample falls inside the pressure curve dead zone.
  bool isPressureDeadZoneForSample(StylusSample? stylusSample) {
    final input = pressureCurveInputForSample(stylusSample);
    if (input == null) return false;
    return pressureCurve.isDeadZone(input);
  }

  /// Returns the pressure value that will be passed through the pressure curve.
  double? pressureCurveInputForSample(StylusSample? stylusSample) {
    if (stylusSample == null) return null;
    if (toolId != ToolId.pencil) return stylusSample.pressure;

    final pressure = stylusSample.pressure;
    final tilt = stylusSample.tilt;
    if (tilt == null) return pressure;
    if (pressure == null && tilt == 0) return null;

    final basePressure = pressure ?? 0.5;
    final normalizedTilt = (tilt.abs() / (math.pi / 2)).clamp(0.0, 1.0);
    return (basePressure + normalizedTilt * tiltSensitivity)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double? _effectivePressure(StylusSample? stylusSample) {
    return effectivePressureForSample(stylusSample);
  }

  Stroke _newStroke({required EditorPage page, required int pageIndex}) {
    return Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(isComplete: false),
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
      rollSensitivity: rollSensitivity,
    );
  }

  Stroke? _newStrokeFromCurrentPage() {
    final page = _currentStrokePage;
    final pageIndex = _currentStrokePageIndex;
    if (page == null || pageIndex == null) return null;
    return _newStroke(page: page, pageIndex: pageIndex);
  }

  Stroke? _finishCurrentStrokeSegment() {
    final stroke = currentStroke;
    currentStroke = null;
    _currentStrokeStartTimestamp = null;
    if (stroke == null || stroke.isEmpty) return null;

    return stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
  }
}
