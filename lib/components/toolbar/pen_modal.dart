/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/toolbar/size_picker.dart';
import 'package:saber/data/extensions/axis_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

class PenModal extends StatefulWidget {
  const PenModal({super.key, required this.getTool, required this.setTool});

  final Tool Function() getTool;
  final void Function(Pen) setTool;

  @override
  State<PenModal> createState() => _PenModalState();
}

class _PenModalState extends State<PenModal> {
  @override
  Widget build(BuildContext context) {
    final axis = stows.editorToolbarAlignment.value.axis.opposite;
    final Tool currentTool = widget.getTool();
    final Pen currentPen;
    if (currentTool is Pen) {
      currentPen = currentTool;
    } else {
      return const SizedBox();
    }

    return Flex(
      direction: axis,
      mainAxisAlignment: .center,
      children: [
        SizePicker(axis: axis, pen: currentPen),
        const SizedBox.square(dimension: 8),
        IconButton(
          tooltip: t.editor.penOptions.advancedSettings,
          icon: const Icon(Icons.tune),
          onPressed: () => _showAdvancedSettings(currentPen),
        ),
        if (currentPen is! Highlighter && currentPen is! Pencil) ...[
          const SizedBox.square(dimension: 8),
          IconButton(
            onPressed: () => setState(() {
              widget.setTool(Pen.fountainPen());
            }),
            style: TextButton.styleFrom(
              foregroundColor: Pen.currentPen.icon == Pen.fountainPenIcon
                  ? ColorScheme.of(context).secondary
                  : ColorScheme.of(context).onSurface,
              backgroundColor: Pen.currentPen.icon == Pen.fountainPenIcon
                  ? Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: const CircleBorder(),
            ),
            tooltip: t.editor.pens.fountainPen,
            icon: SvgPicture.asset(
              'assets/images/scribble_fountain.svg',
              width: 32,
              height: 32 / 508 * 374,
              theme: SvgTheme(
                currentColor: Pen.currentPen.icon == Pen.fountainPenIcon
                    ? ColorScheme.of(context).secondary
                    : ColorScheme.of(context).onSurface,
              ),
            ),
          ),
          const SizedBox.square(dimension: 8),
          IconButton(
            onPressed: () => setState(() {
              widget.setTool(Pen.ballpointPen());
            }),
            style: TextButton.styleFrom(
              foregroundColor: Pen.currentPen.icon == Pen.ballpointPenIcon
                  ? ColorScheme.of(context).secondary
                  : ColorScheme.of(context).onSurface,
              backgroundColor: Pen.currentPen.icon == Pen.ballpointPenIcon
                  ? Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: const CircleBorder(),
            ),
            tooltip: t.editor.pens.ballpointPen,
            icon: SvgPicture.asset(
              'assets/images/scribble_ballpoint.svg',
              width: 32,
              height: 32 / 508 * 374,
              theme: SvgTheme(
                currentColor: Pen.currentPen.icon == Pen.ballpointPenIcon
                    ? ColorScheme.of(context).secondary
                    : ColorScheme.of(context).onSurface,
              ),
            ),
          ),
          const SizedBox.square(dimension: 8),
          IconButton(
            onPressed: () => setState(() {
              widget.setTool(ShapePen());
            }),
            style: TextButton.styleFrom(
              foregroundColor: Pen.currentPen.icon == ShapePen.shapePenIcon
                  ? ColorScheme.of(context).secondary
                  : ColorScheme.of(context).onSurface,
              backgroundColor: Pen.currentPen.icon == ShapePen.shapePenIcon
                  ? Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1)
                  : Colors.transparent,
              shape: const CircleBorder(),
            ),
            tooltip: t.editor.pens.shapePen,
            icon: const FaIcon(ShapePen.shapePenIcon),
          ),
        ],
      ],
    );
  }

  Future<void> _showAdvancedSettings(Pen pen) async {
    Pen.advancedSettingsOpen.value = true;
    try {
      final applied = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PenAdvancedSettingsDialog(pen: pen),
      );
      if (!mounted) return;
      if (applied == true) setState(() {});
    } finally {
      Pen.advancedSettingsOpen.value = false;
    }
  }
}

class _PenAdvancedSettingsDialog extends StatefulWidget {
  const _PenAdvancedSettingsDialog({required this.pen});

  final Pen pen;

  @override
  State<_PenAdvancedSettingsDialog> createState() =>
      _PenAdvancedSettingsDialogState();
}

class _PenAdvancedSettingsDialogState
    extends State<_PenAdvancedSettingsDialog> {
  static _PenAdvancedSettingsDraft? _clipboard;

  late _PenAdvancedSettingsDraft _draft;
  late _AdvancedOptionKey _activeOption;
  var _curveEditing = false;

  @override
  void initState() {
    super.initState();
    _draft = _PenAdvancedSettingsDraft.fromPen(widget.pen);
    _activeOption = _draft.pressureEnabled
        ? _AdvancedOptionKey.curve
        : _AdvancedOptionKey.smoothing;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final preferredWidth = _draft.pressureEnabled ? 920.0 : 560.0;
    final dialogWidth = math.min(preferredWidth, screenSize.width - 48);
    final dialogHeight = math.min(640.0, screenSize.height - 48);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.editor.penOptions.advancedSettings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    _toolName(_draft.toolId),
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _contentPanel()),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(t.common.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      _draft.applyTo(widget.pen);
                      Navigator.of(context).pop(true);
                    },
                    child: Text(t.editor.penOptions.applyAdvancedSettings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentPanel() {
    if (!_draft.pressureEnabled) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _settingsPanel(),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: _curvePanel()),
        const SizedBox(width: 16),
        Expanded(flex: 1, child: _settingsPanel()),
      ],
    );
  }

  Widget _curvePanel() {
    return _HoverableOptionPanel(
      active: _activeOption == _AdvancedOptionKey.curve || _curveEditing,
      onFocus: () => _focusOption(_AdvancedOptionKey.curve),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PenOptionHeader(
            label: t.editor.penOptions.pressureCurve,
            description: t.editor.penOptions.pressureCurveDescription,
            trailing: IconButton(
              tooltip: t.editor.penOptions.resetPressureCurve,
              icon: const Icon(Icons.restart_alt),
              onPressed: () {
                _exitCurveEditing();
                setState(() {
                  _draft = _draft.copyWith(
                    pressureCurve: PressureCurve.neutral(),
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _PressureCurveEditor(
              curve: _draft.pressureCurve,
              editing: _curveEditing,
              onEditingChanged: (editing) {
                setState(() {
                  _activeOption = _AdvancedOptionKey.curve;
                  _curveEditing = editing;
                });
              },
              onChanged: (curve) {
                setState(() => _draft = _draft.copyWith(pressureCurve: curve));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HoverableOptionPanel(
            active: _activeOption == _AdvancedOptionKey.copyPaste,
            onFocus: () => _focusOption(_AdvancedOptionKey.copyPaste),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _focusOption(_AdvancedOptionKey.copyPaste);
                      setState(() => _clipboard = _draft.copy());
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(t.editor.penOptions.copyPresetTo),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clipboard == null
                        ? null
                        : () {
                            _focusOption(_AdvancedOptionKey.copyPaste);
                            setState(() {
                              _draft = _draft.copyCompatibleFrom(_clipboard!);
                            });
                          },
                    icon: const Icon(Icons.content_paste, size: 16),
                    label: Text(t.editor.penOptions.copyPresetFrom),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sliderOption(
            key: _AdvancedOptionKey.smoothing,
            label: t.editor.penOptions.smoothing,
            description: t.editor.penOptions.smoothingDescription,
            value: _draft.options.smoothing,
            onChanged: (value) {
              setState(() {
                _draft.options.smoothing = value;
              });
            },
          ),
          _sliderOption(
            key: _AdvancedOptionKey.streamline,
            label: t.editor.penOptions.streamline,
            description: t.editor.penOptions.streamlineDescription,
            value: _draft.options.streamline,
            onChanged: (value) {
              setState(() {
                _draft.options.streamline = value;
              });
            },
          ),
          if (_draft.pressureEnabled)
            _sliderOption(
              key: _AdvancedOptionKey.pressureWidth,
              label: t.editor.penOptions.pressureWidth,
              description: t.editor.penOptions.pressureWidthDescription,
              value: _draft.options.thinning,
              onChanged: (value) {
                setState(() {
                  _draft.options.thinning = value;
                });
              },
            ),
          if (_draft.toolId == ToolId.pencil)
            _sliderOption(
              key: _AdvancedOptionKey.tilt,
              label: t.editor.penOptions.tiltSensitivity,
              description: t.editor.penOptions.tiltSensitivityDescription,
              value: _draft.tiltSensitivity,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(tiltSensitivity: value);
                });
              },
            ),
          if (_draft.toolId == ToolId.pencil ||
              _draft.toolId == ToolId.fountainPen)
            _sliderOption(
              key: _AdvancedOptionKey.roll,
              label: t.editor.penOptions.rollSensitivity,
              description: t.editor.penOptions.rollSensitivityDescription,
              value: _draft.rollSensitivity,
              onChanged: (value) {
                setState(() {
                  _draft = _draft.copyWith(rollSensitivity: value);
                });
              },
            ),
          _sliderOption(
            key: _AdvancedOptionKey.continuousWriting,
            label: t.editor.penOptions.continuousWritingWindow,
            description: t.editor.penOptions.continuousWritingWindowDescription,
            value: _draft.continuousWritingWindowMs.toDouble(),
            valueText: '${_draft.continuousWritingWindowMs} ms',
            min: 0,
            max: 2000,
            divisions: 40,
            onChanged: (value) {
              setState(() {
                _draft = _draft.copyWith(
                  continuousWritingWindowMs: value.round(),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderOption({
    required _AdvancedOptionKey key,
    required String label,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
    String? valueText,
    double min = 0,
    double max = 1,
    int divisions = 20,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _HoverableOptionPanel(
        active: _activeOption == key,
        onFocus: () => _focusOption(key),
        child: _PenOptionSlider(
          label: label,
          description: description,
          value: value,
          valueText: valueText ?? _formatPercent(value),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _focusOption(_AdvancedOptionKey option) {
    setState(() {
      _activeOption = option;
      _curveEditing = false;
    });
  }

  void _exitCurveEditing() {
    if (!_curveEditing) return;
    setState(() => _curveEditing = false);
  }

  static String _formatPercent(double value) => '${(value * 100).round()}%';

  static String _toolName(ToolId toolId) {
    return switch (toolId) {
      ToolId.fountainPen => t.editor.pens.fountainPen,
      ToolId.ballpointPen => t.editor.pens.ballpointPen,
      ToolId.highlighter => t.editor.pens.highlighter,
      ToolId.pencil => t.editor.pens.pencil,
      ToolId.shapePen => t.editor.pens.shapePen,
      _ => '',
    };
  }
}

enum _AdvancedOptionKey {
  curve,
  copyPaste,
  smoothing,
  streamline,
  pressureWidth,
  tilt,
  roll,
  continuousWriting,
}

class _PenAdvancedSettingsDraft {
  _PenAdvancedSettingsDraft({
    required this.toolId,
    required this.pressureEnabled,
    required this.options,
    required this.pressureCurve,
    required this.tiltSensitivity,
    required this.rollSensitivity,
    required this.continuousWritingWindowMs,
  });

  factory _PenAdvancedSettingsDraft.fromPen(Pen pen) {
    return _PenAdvancedSettingsDraft(
      toolId: pen.toolId,
      pressureEnabled: pen.pressureEnabled,
      options: pen.options.copyWith(),
      pressureCurve: pen.pressureCurve,
      tiltSensitivity: pen.tiltSensitivity,
      rollSensitivity: pen.rollSensitivity,
      continuousWritingWindowMs:
          stows.continuousWritingAutoStraightenWindowMs.value,
    );
  }

  final ToolId toolId;
  final bool pressureEnabled;
  final StrokeOptions options;
  final PressureCurve pressureCurve;
  final double tiltSensitivity;
  final double rollSensitivity;
  final int continuousWritingWindowMs;

  _PenAdvancedSettingsDraft copyWith({
    StrokeOptions? options,
    PressureCurve? pressureCurve,
    double? tiltSensitivity,
    double? rollSensitivity,
    int? continuousWritingWindowMs,
  }) {
    return _PenAdvancedSettingsDraft(
      toolId: toolId,
      pressureEnabled: pressureEnabled,
      options: options ?? this.options,
      pressureCurve: pressureCurve ?? this.pressureCurve,
      tiltSensitivity: tiltSensitivity ?? this.tiltSensitivity,
      rollSensitivity: rollSensitivity ?? this.rollSensitivity,
      continuousWritingWindowMs:
          continuousWritingWindowMs ?? this.continuousWritingWindowMs,
    );
  }

  _PenAdvancedSettingsDraft copy() {
    return copyWith(
      options: options.copyWith(),
      pressureCurve: PressureCurve(pressureCurve.points),
    );
  }

  _PenAdvancedSettingsDraft copyCompatibleFrom(
    _PenAdvancedSettingsDraft source,
  ) {
    final copiedOptions = options.copyWith(
      smoothing: source.options.smoothing,
      streamline: source.options.streamline,
      thinning: source.options.thinning,
    );

    return copyWith(
      options: copiedOptions,
      pressureCurve: pressureEnabled && source.pressureEnabled
          ? PressureCurve(source.pressureCurve.points)
          : pressureCurve,
      tiltSensitivity: toolId == ToolId.pencil && source.toolId == ToolId.pencil
          ? source.tiltSensitivity
          : tiltSensitivity,
      rollSensitivity: _usesRoll(toolId) && _usesRoll(source.toolId)
          ? source.rollSensitivity
          : rollSensitivity,
      continuousWritingWindowMs: source.continuousWritingWindowMs,
    );
  }

  void applyTo(Pen pen) {
    pen.options.smoothing = options.smoothing;
    pen.options.streamline = options.streamline;
    pen.options.thinning = options.thinning;
    if (pen.pressureEnabled) pen.pressureCurve = pressureCurve;
    if (pen.toolId == ToolId.pencil) pen.tiltSensitivity = tiltSensitivity;
    if (_usesRoll(pen.toolId)) pen.rollSensitivity = rollSensitivity;

    stows.continuousWritingAutoStraightenWindowMs.value =
        continuousWritingWindowMs;
    _persist(pen);
  }

  static bool _usesRoll(ToolId toolId) {
    return toolId == ToolId.pencil || toolId == ToolId.fountainPen;
  }

  static void _persist(Pen pen) {
    switch (pen.toolId) {
      case ToolId.fountainPen:
        stows.lastFountainPenPressureCurveLegacy.value = 0;
        stows.lastFountainPenPressureCurve.value = pen.pressureCurve;
        stows.lastFountainPenRollSensitivity.value = pen.rollSensitivity;
        stows.lastFountainPenOptions.notifyListeners();
      case ToolId.ballpointPen:
        stows.lastBallpointPenOptions.notifyListeners();
      case ToolId.highlighter:
        stows.lastHighlighterOptions.notifyListeners();
      case ToolId.pencil:
        stows.lastPencilPressureCurveLegacy.value = 0;
        stows.lastPencilPressureCurve.value = pen.pressureCurve;
        stows.lastPencilTiltSensitivity.value = pen.tiltSensitivity;
        stows.lastPencilRollSensitivity.value = pen.rollSensitivity;
        stows.lastPencilOptions.notifyListeners();
      case ToolId.shapePen:
        stows.lastShapePenOptions.notifyListeners();
      case _:
        break;
    }
  }
}

class _HoverableOptionPanel extends StatefulWidget {
  const _HoverableOptionPanel({
    required this.child,
    required this.onFocus,
    this.active = false,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final VoidCallback onFocus;
  final bool active;
  final EdgeInsetsGeometry padding;

  @override
  State<_HoverableOptionPanel> createState() => _HoverableOptionPanelState();
}

class _HoverableOptionPanelState extends State<_HoverableOptionPanel> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final highlighted = _hovered || widget.active;
    return Listener(
      onPointerDown: (_) => widget.onFocus(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: highlighted
                ? colorScheme.secondary.withValues(alpha: 0.10)
                : colorScheme.surface,
            border: Border.all(
              color: highlighted
                  ? colorScheme.secondary.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PenOptionSlider extends StatelessWidget {
  const _PenOptionSlider({
    required this.label,
    required this.description,
    required this.value,
    required this.valueText,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions = 20,
  });

  final String label;
  final String description;
  final double value;
  final String valueText;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PenOptionHeader(
          label: label,
          description: description,
          trailing: Text(
            valueText,
            style: TextStyle(
              color: ColorScheme.of(context).onSurface.withValues(alpha: 0.72),
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.1,
            ),
          ),
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PenOptionHeader extends StatelessWidget {
  const _PenOptionHeader({
    required this.label,
    required this.description,
    this.trailing,
  });

  final String label;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 3),
        Text(
          description,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.62),
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _PressureCurveEditor extends StatefulWidget {
  const _PressureCurveEditor({
    required this.curve,
    required this.onChanged,
    required this.editing,
    required this.onEditingChanged,
  });

  final PressureCurve curve;
  final ValueChanged<PressureCurve> onChanged;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;

  @override
  State<_PressureCurveEditor> createState() => _PressureCurveEditorState();
}

class _PressureCurveEditorState extends State<_PressureCurveEditor> {
  static const _deleteRadius = 38.0;
  static const _handleRadius = 7.0;
  static const _handleRadiusActive = 9.0;
  static const _maxControlPoints = 12;
  static const _snapRadius = 34.0;

  int? _activePointIndex;

  @override
  void didUpdateWidget(covariant _PressureCurveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing && _activePointIndex != null) {
      _activePointIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _snapToPoint(details.localPosition, size),
          onTapUp: (details) => _addPoint(details.localPosition, size),
          onPanDown: (details) => _startDrag(details.localPosition, size),
          onPanStart: (details) => _startDrag(details.localPosition, size),
          onPanUpdate: (details) => _dragPoint(details.localPosition, size),
          onLongPressStart: (details) =>
              _deletePoint(details.localPosition, size),
          child: CustomPaint(
            painter: _PressureCurvePainter(
              curve: widget.curve,
              colorScheme: ColorScheme.of(context),
              activePointIndex: _activePointIndex,
              editing: widget.editing,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _snapToPoint(Offset position, Size size) {
    final nearestIndex = _nearestPoint(position, size);
    if (nearestIndex == null) return;

    widget.onEditingChanged(true);
    setState(() => _activePointIndex = nearestIndex);
  }

  void _addPoint(Offset position, Size size) {
    widget.onEditingChanged(true);
    final nearestIndex = _nearestPoint(position, size);
    if (nearestIndex != null) {
      setState(() => _activePointIndex = nearestIndex);
      return;
    }

    if (widget.curve.points.length >= _maxControlPoints) return;

    final point = _clampedPointFromPosition(position, size);
    final curve = widget.curve.copyWithPoints([...widget.curve.points, point]);
    widget.onChanged(curve);
    setState(() => _activePointIndex = _nearestInput(point.input, curve));
  }

  void _startDrag(Offset position, Size size) {
    widget.onEditingChanged(true);
    final nearestIndex = _nearestPoint(position, size);
    if (nearestIndex != null) {
      setState(() => _activePointIndex = nearestIndex);
      return;
    }

    _addPoint(position, size);
  }

  void _dragPoint(Offset position, Size size) {
    widget.onEditingChanged(true);
    final index = _activePointIndex;
    if (index == null) return;

    final points = [...widget.curve.points];
    final point = _pointFromPosition(position, size);
    final input = switch (index) {
      0 => 0.0,
      final i when i == points.length - 1 => 1.0,
      _ =>
        point.input
            .clamp(
              points[index - 1].input + 0.02,
              points[index + 1].input - 0.02,
            )
            .toDouble(),
    };
    final output = switch (index) {
      0 => 0.0,
      final i when i == points.length - 1 => 1.0,
      _ =>
        point.output
            .clamp(points[index - 1].output, points[index + 1].output)
            .toDouble(),
    };
    points[index] = PressureCurvePoint(input: input, output: output);
    widget.onChanged(widget.curve.copyWithPoints(points));
  }

  void _deletePoint(Offset position, Size size) {
    widget.onEditingChanged(true);
    final nearestIndex = _nearestPoint(
      position,
      size,
      threshold: _deleteRadius,
    );
    if (nearestIndex == null) return;
    if (nearestIndex == 0 || nearestIndex == widget.curve.points.length - 1) {
      return;
    }

    final points = [...widget.curve.points]..removeAt(nearestIndex);
    widget.onChanged(widget.curve.copyWithPoints(points));
    setState(() => _activePointIndex = null);
  }

  int? _nearestPoint(
    Offset position,
    Size size, {
    double threshold = _snapRadius,
  }) {
    var nearestDistance = double.infinity;
    int? nearestIndex;
    for (var i = 0; i < widget.curve.points.length; i++) {
      final pointPosition = _positionFromPoint(widget.curve.points[i], size);
      final distance = (pointPosition - position).distance;
      if (distance >= nearestDistance) continue;
      nearestDistance = distance;
      nearestIndex = i;
    }

    if (nearestDistance > threshold) return null;
    return nearestIndex;
  }

  int _nearestInput(double input, PressureCurve curve) {
    var nearestDistance = double.infinity;
    var nearestIndex = 0;
    for (var i = 0; i < curve.points.length; i++) {
      final distance = (curve.points[i].input - input).abs();
      if (distance >= nearestDistance) continue;
      nearestDistance = distance;
      nearestIndex = i;
    }
    return nearestIndex;
  }

  PressureCurvePoint _clampedPointFromPosition(Offset position, Size size) {
    final point = _pointFromPosition(position, size);
    final points = widget.curve.points;
    var previous = points.first;
    var next = points.last;
    for (var i = 1; i < points.length; i++) {
      if (points[i].input < point.input) {
        previous = points[i];
        continue;
      }
      next = points[i];
      break;
    }

    return PressureCurvePoint(
      input: point.input,
      output: point.output.clamp(previous.output, next.output).toDouble(),
    );
  }

  PressureCurvePoint _pointFromPosition(Offset position, Size size) {
    final plotRect = _PressureCurvePainter.plotRect(size);
    return PressureCurvePoint(
      input: ((position.dx - plotRect.left) / plotRect.width)
          .clamp(0.0, 1.0)
          .toDouble(),
      output: (1 - (position.dy - plotRect.top) / plotRect.height)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  Offset _positionFromPoint(PressureCurvePoint point, Size size) {
    final plotRect = _PressureCurvePainter.plotRect(size);
    return Offset(
      plotRect.left + point.input * plotRect.width,
      plotRect.bottom - point.output * plotRect.height,
    );
  }
}

class _PressureCurvePainter extends CustomPainter {
  const _PressureCurvePainter({
    required this.curve,
    required this.colorScheme,
    required this.editing,
    this.activePointIndex,
  });

  final PressureCurve curve;
  final ColorScheme colorScheme;
  final bool editing;
  final int? activePointIndex;

  static Rect plotRect(Size size) {
    return Rect.fromLTWH(42, 18, size.width - 58, size.height - 46);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = _PressureCurvePainter.plotRect(size);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = editing ? 1.8 : 1
      ..color = editing
          ? colorScheme.secondary
          : colorScheme.outlineVariant.withValues(alpha: 0.95);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.58);
    final diagonalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.onSurface.withValues(alpha: 0.24);
    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = colorScheme.secondary;

    canvas.drawRect(plotRect, borderPaint);

    for (var i = 1; i < 4; i++) {
      final x = plotRect.left + plotRect.width * i / 4;
      final y = plotRect.top + plotRect.height * i / 4;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }

    canvas.drawLine(plotRect.bottomLeft, plotRect.topRight, diagonalPaint);

    final path = Path();
    for (var i = 0; i <= plotRect.width.round(); i++) {
      final input = i / plotRect.width;
      final output = curve.apply(input);
      final point = Offset(
        plotRect.left + i.toDouble(),
        plotRect.bottom - output * plotRect.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, curvePaint);

    _paintControlPoints(canvas, plotRect);
    _paintAxisLabels(canvas, plotRect);
  }

  void _paintControlPoints(Canvas canvas, Rect plotRect) {
    for (var i = 0; i < curve.points.length; i++) {
      final point = curve.points[i];
      final position = Offset(
        plotRect.left + point.input * plotRect.width,
        plotRect.bottom - point.output * plotRect.height,
      );
      final isActive = i == activePointIndex;
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isActive ? colorScheme.secondary : colorScheme.surface;
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3 : 2.2
        ..color = colorScheme.secondary;
      final radius = isActive
          ? _PressureCurveEditorState._handleRadiusActive
          : _PressureCurveEditorState._handleRadius;

      canvas.drawCircle(position, radius, fillPaint);
      canvas.drawCircle(position, radius, strokePaint);
    }
  }

  void _paintAxisLabels(Canvas canvas, Rect plotRect) {
    _paintLabel(canvas, '0%', Offset(plotRect.left - 26, plotRect.bottom - 8));
    _paintLabel(canvas, '100%', Offset(plotRect.left - 38, plotRect.top - 5));
    _paintLabel(canvas, '0%', Offset(plotRect.left - 5, plotRect.bottom + 8));
    _paintLabel(
      canvas,
      '100%',
      Offset(plotRect.right - 24, plotRect.bottom + 8),
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.54),
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PressureCurvePainter oldDelegate) {
    return oldDelegate.curve != curve ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.activePointIndex != activePointIndex ||
        oldDelegate.editing != editing;
  }
}
