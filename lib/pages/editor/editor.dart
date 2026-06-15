/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:collapsible/collapsible.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, kDebugMode, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:keybinder/keybinder.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas.dart';
import 'package:saber/components/canvas/canvas_gesture_detector.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/editor/read_only_banner.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/editor_bottom_sheet.dart';
import 'package:saber/components/toolbar/editor_page_manager.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/apple_pencil/apple_pencil_interaction.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_exporter.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';
import 'package:saber/data/extensions/matrix4_extensions.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/peripheral_debug_data.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/data/tools/stylus_hover_preview.dart';
import 'package:saber/data/tools/stylus_pose.dart';
import 'package:saber/data/tools/stylus_sample.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:sbn/change.dart';
import 'package:super_clipboard/super_clipboard.dart';

typedef _PhotoInfo = ({Uint8List bytes, String extension});
typedef _ApplePencilInteractionSubscription =
    StreamSubscription<ApplePencilInteractionEvent>;
typedef _ApplePencilHoverSubscription =
    StreamSubscription<ApplePencilHoverEvent>;
typedef _ApplePencilTelemetrySubscription =
    StreamSubscription<ApplePencilTelemetryEvent>;

class Editor extends StatefulWidget {
  Editor({
    super.key,
    String? path,
    this.customTitle,
    this.pdfPath,
    this.applePencilInteractionService,
    this.applePencilHoverService,
    this.applePencilTelemetryService,
  }) : initialPath = path != null
           ? Future.value(path)
           : FileManager.newFilePath('/'),
       needsNaming = path == null;

  final Future<String> initialPath;
  final bool needsNaming;

  final String? customTitle;
  final String? pdfPath;

  /// Provides Apple Pencil hardware events.
  ///
  /// Tests can inject a fake service to avoid the native iOS channel.
  final ApplePencilInteractionService? applePencilInteractionService;

  /// Provides Apple Pencil hover events.
  ///
  /// Tests can inject a fake service to avoid the native iOS channel.
  final ApplePencilHoverService? applePencilHoverService;

  /// Provides native Apple Pencil writing telemetry events.
  ///
  /// Tests can inject a fake service to avoid the native iOS channel.
  final ApplePencilTelemetryService? applePencilTelemetryService;

  /// The file extension used by the app.
  /// Files with this extension are
  /// encoded in BSON format.
  static const extension = '.sbn2';

  /// The old file extension used by the app.
  /// Files with this extension are
  /// encoded in JSON format.
  static const extensionOldJson = '.sbn';

  static const double gapBetweenPages = 16;

  /// Returns true if [path] belongs to a hidden file
  /// used by other functions of the app
  static bool isReservedPath(String path) {
    return _reservedFilePaths.any((regex) => regex.hasMatch(path));
  }

  static final _reservedFilePaths = <RegExp>[
    RegExp(RegExp.escape(Whiteboard.filePath)),
  ];

  /// Whether the platform can rasterize a pdf
  static var canRasterPdf = true;

  @override
  State<Editor> createState() => EditorState();
}

class _PeripheralDebugOverlay extends StatelessWidget {
  const _PeripheralDebugOverlay({required this.dataListenable});

  final ValueListenable<PeripheralDebugData?> dataListenable;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: ValueListenableBuilder(
                valueListenable: dataListenable,
                builder: (context, data, _) {
                  final colorScheme = ColorScheme.of(context);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.88),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.9,
                        ),
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 11,
                          height: 1.18,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        child: data == null
                            ? Text(
                                t.settings.prefLabels.peripheralDebugDataWindow,
                              )
                            : _PeripheralDebugDataTable(data: data),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeripheralDebugDataTable extends StatelessWidget {
  const _PeripheralDebugDataTable({required this.data});

  final PeripheralDebugData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.settings.prefLabels.peripheralDebugDataWindow,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _DebugDataRow(label: 'source', value: data.source),
        _DebugDataRow(label: 'active', value: data.active ? 'yes' : 'no'),
        _DebugDataRow(label: 'kind', value: data.kind?.name ?? '--'),
        _DebugDataRow(
          label: 'page',
          value: data.pageIndex == null ? '--' : '${data.pageIndex! + 1}',
        ),
        _DebugDataRow(
          label: 'global',
          value: _formatOffset(data.globalPosition),
        ),
        _DebugDataRow(
          label: 'page xy',
          value: _formatOffset(data.pagePosition),
        ),
        _DebugDataRow(
          label: 'pressure raw',
          value: _formatPercent(data.rawPressure),
        ),
        _DebugDataRow(
          label: 'pressure curve',
          value: _formatPercent(data.effectivePressure),
        ),
        _DebugDataRow(label: 'force', value: _formatForce(data)),
        _DebugDataRow(label: 'hover', value: _formatHover(data)),
        _DebugDataRow(label: 'tilt', value: _formatAngle(data.tilt)),
        _DebugDataRow(
          label: 'orientation',
          value: _formatAngle(data.orientation),
        ),
        _DebugDataRow(
          label: 'altitude',
          value: _formatAngle(data.altitudeAngle),
        ),
        _DebugDataRow(label: 'azimuth', value: _formatAngle(data.azimuthAngle)),
        _DebugDataRow(label: 'roll', value: _formatAngle(data.rollAngle)),
        _DebugDataRow(label: 'radius', value: _formatNumber(data.majorRadius)),
        _DebugDataRow(label: 'timestamp', value: _formatNumber(data.timestamp)),
        _DebugDataRow(
          label: 'flags',
          value: data.sourceFlags?.toString() ?? '--',
        ),
        _DebugDataRow(
          label: 'samples',
          value:
              '${data.coalescedCount ?? 0} coalesced / ${data.predictedCount ?? 0} predicted',
        ),
      ],
    );
  }

  static String _formatOffset(Offset? value) {
    if (value == null) return '--';
    return '${value.dx.toStringAsFixed(1)}, ${value.dy.toStringAsFixed(1)}';
  }

  static String _formatPercent(double? value) {
    if (value == null) return '--';
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String _formatNumber(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(3);
  }

  static String _formatAngle(double? value) {
    if (value == null) return '--';
    return '${(value * 180 / math.pi).toStringAsFixed(1)} deg';
  }

  static String _formatForce(PeripheralDebugData data) {
    if (data.force == null) return '--';
    final force = data.force!.toStringAsFixed(3);
    final maxForce = data.maximumPossibleForce?.toStringAsFixed(3);
    if (maxForce == null) return force;
    return '$force / $maxForce';
  }

  static String _formatHover(PeripheralDebugData data) {
    if (data.hoverDistance == null) return '--';
    final distance = data.hoverDistance!.toStringAsFixed(3);
    final maxDistance = data.hoverDistanceMax?.toStringAsFixed(3);
    if (maxDistance == null) return distance;
    return '$distance / $maxDistance';
  }
}

class _DebugDataRow extends StatelessWidget {
  const _DebugDataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 98,
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}

class EditorState extends State<Editor> {
  /// Consecutive handwriting strokes inside this interval skip auto-straighten.
  static const continuousWritingAutoStraightenSuppressionWindow = Duration(
    milliseconds: 900,
  );

  /// Returns whether auto-straighten should pause for continuous handwriting.
  static bool shouldSuppressAutoStraightenForContinuousWriting({
    required DateTime? previousStrokeEndedAt,
    required DateTime currentStrokeStartedAt,
    Duration window = continuousWritingAutoStraightenSuppressionWindow,
  }) {
    if (previousStrokeEndedAt == null) return false;
    if (window <= Duration.zero) return false;

    final gap = currentStrokeStartedAt.difference(previousStrokeEndedAt);
    return gap >= Duration.zero && gap <= window;
  }

  final log = Logger('EditorState');

  late var coreInfo = EditorCoreInfo.placeholder;

  final _canvasGestureDetectorKey = GlobalKey<CanvasGestureDetectorState>();
  final _toolbarKey = GlobalKey<ToolbarState>();
  _ApplePencilInteractionSubscription? _applePencilInteractionSubscription;
  _ApplePencilHoverSubscription? _applePencilHoverSubscription;
  _ApplePencilTelemetrySubscription? _applePencilTelemetrySubscription;
  Timer? _applePencilSubscriptionTimer;
  final _transformationController = TransformationController();
  double get scrollY {
    final transformation = _transformationController.value;
    final scale = transformation.approxScale;
    final translation = transformation.getTranslation();
    final gestureDetector = _canvasGestureDetectorKey.currentState;

    if (gestureDetector == null) {
      log.warning('scrollY: Could not find CanvasGestureDetectorState');
      return translation.y / scale;
    } else {
      final middle = gestureDetector.containerBounds.maxHeight / 2;
      return (translation.y - middle) / scale + middle;
    }
  }

  var history = EditorHistory();

  late bool needsNaming = widget.needsNaming && stows.editorPromptRename.value;

  late Tool _currentTool = () {
    switch (stows.lastTool.value) {
      case .fountainPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.fountainPen();
        }
        return Pen.currentPen;
      case .ballpointPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.ballpointPen();
        }
        return Pen.currentPen;
      case .shapePen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = ShapePen();
        }
        return Pen.currentPen;
      case .highlighter:
        return Highlighter.currentHighlighter;
      case .pencil:
        return Pencil.currentPencil;
      case .eraser:
        return Eraser();
      case .select:
        return Select.currentSelect;
      case .textEditing:
        return Tool.textEditing;
      case .laserPointer:
        return LaserPointer.currentLaserPointer;
    }
  }();
  Tool get currentTool => _currentTool;
  set currentTool(Tool tool) {
    if (tool is! Eraser && tool != _lastNonEraserTool) {
      _previousNonTransientTool = _lastNonEraserTool;
      _lastNonEraserTool = tool;
    }
    _currentTool = tool;
    stows.lastTool.value = tool.toolId;
  }

  ValueNotifier<SavingState> savingState = ValueNotifier(SavingState.saved);
  final _peripheralDebugData = ValueNotifier<PeripheralDebugData?>(null);
  Timer? _delayedSaveTimer;
  Timer? _watchServerTimer;

  // used to prevent accidentally drawing when pinch zooming
  var lastSeenPointerCount = 0;
  Timer? _lastSeenPointerCountTimer;

  ValueNotifier<QuillStruct?> quillFocus = ValueNotifier(null);

  /// The last non-Eraser [currentTool] value.
  late Tool _lastNonEraserTool = _currentTool is Eraser
      ? Pen.currentPen
      : _currentTool;
  Tool? _previousNonTransientTool;

  /// If the stylus button is pressed, or was pressed, during the current draw gesture.
  ///
  /// For now, this also includes when an [PointerDeviceKind.inverseStylus] is
  /// used since the stylus rear-end and stylus button currently act the same.
  /// If we add customized button bindings, we may have to separate this again.
  var stylusButtonWasPressed = false;
  StylusHoverPreview? _stylusHoverPreview;

  /// The current stylus hover preview, exposed for editor behavior tests.
  @visibleForTesting
  StylusHoverPreview? get stylusHoverPreview => _stylusHoverPreview;

  Tool? _applePencilSqueezeRestoreTool;
  var _applePencilSqueezeEraserActive = false;

  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    Pen.advancedSettingsOpen.addListener(_onPenAdvancedSettingsOpenChanged);

    _scheduleApplePencilSubscriptions();
    _initAsync();
    _assignKeybindings();

    super.initState();
  }

  void _onPenAdvancedSettingsOpenChanged() {
    if (!Pen.advancedSettingsOpen.value) return;
    clearStylusHoverPreview();
  }

  void _scheduleApplePencilSubscriptions() {
    final hasInjectedService =
        widget.applePencilInteractionService != null ||
        widget.applePencilHoverService != null ||
        widget.applePencilTelemetryService != null;
    if (hasInjectedService) {
      _listenToApplePencilServices();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applePencilSubscriptionTimer = Timer(
        const Duration(milliseconds: 350),
        _listenToApplePencilServices,
      );
    });
  }

  void _listenToApplePencilServices() {
    if (!mounted) return;
    _listenToApplePencilInteractions();
    _listenToApplePencilHover();
    _listenToApplePencilTelemetry();
  }

  void _listenToApplePencilInteractions() {
    final service =
        widget.applePencilInteractionService ??
        const EventChannelApplePencilInteractionService();
    _applePencilInteractionSubscription = service.events.listen(
      _handleApplePencilInteraction,
      onError: (Object error, StackTrace stackTrace) {
        log.warning(
          'Apple Pencil interaction stream failed',
          error,
          stackTrace,
        );
      },
    );
  }

  void _listenToApplePencilHover() {
    final service =
        widget.applePencilHoverService ??
        const EventChannelApplePencilHoverService();
    _applePencilHoverSubscription = service.events.listen(
      _handleApplePencilHover,
      onError: (Object error, StackTrace stackTrace) {
        log.warning('Apple Pencil hover stream failed', error, stackTrace);
      },
    );
  }

  void _listenToApplePencilTelemetry() {
    final service =
        widget.applePencilTelemetryService ??
        const EventChannelApplePencilTelemetryService();
    _applePencilTelemetrySubscription = service.events.listen(
      _handleApplePencilTelemetry,
      onError: (Object error, StackTrace stackTrace) {
        log.warning('Apple Pencil telemetry stream failed', error, stackTrace);
      },
    );
  }

  void _initAsync() async {
    final filePath = await widget.initialPath;
    filenameTextEditingController.text = p.basename(filePath);

    if (needsNaming) {
      filenameTextEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: filenameTextEditingController.text.length,
      );
    }

    await _loadCoreInfo(filePath);

    if (widget.pdfPath != null) {
      await importPdfFromFilePath(widget.pdfPath!);
    }
  }

  Future _loadCoreInfo(String filePath) async {
    coreInfo = await EditorCoreInfo.loadFromFilePath(filePath);
    if (coreInfo.readOnly) {
      log.info('Loaded file as read-only: ${coreInfo.readOnlyReason}');
    }

    for (int pageIndex = 0; pageIndex < coreInfo.pages.length; pageIndex++) {
      listenToQuillChanges(coreInfo.pages[pageIndex].quill, pageIndex);
    }

    if (coreInfo.isEmpty) {
      createPage(-1);
    } else {
      for (final page in coreInfo.pages) {
        page.backgroundImage?.onMoveImage = onMoveImage;
        page.backgroundImage?.onDeleteImage = onDeleteImage;
        page.backgroundImage?.onMiscChange = autosaveAfterDelay;
        for (final image in page.images) {
          image.onMoveImage = onMoveImage;
          image.onDeleteImage = onDeleteImage;
          image.onMiscChange = autosaveAfterDelay;
        }
      }
    }

    if (currentTool == Tool.textEditing) {
      int pageIndex;
      if (coreInfo.initialPageIndex != null) {
        pageIndex = coreInfo.initialPageIndex!;
      } else {
        pageIndex = 0;
      }
      assert(pageIndex < coreInfo.pages.length);

      quillFocus.value = coreInfo.pages[pageIndex].quill
        ..focusNode.requestFocus();
    }

    if (coreInfo.filePath == Whiteboard.filePath &&
        stows.autoClearWhiteboardOnExit.value &&
        Whiteboard.needsToAutoClearWhiteboard) {
      // clear whiteboard (and add to history)
      clearAllPages();

      // save cleared whiteboard
      await saveToFile();
      Whiteboard.needsToAutoClearWhiteboard = false;
    } else {
      setState(() {});
    }
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlZ, _ctrlY, _ctrlShiftZ;
  void _assignKeybindings() {
    _ctrlZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    _ctrlY = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyY),
    ], inclusive: true);
    _ctrlShiftZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    Keybinder.bind(_ctrlZ!, undo);
    Keybinder.bind(_ctrlY!, redo);
    Keybinder.bind(_ctrlShiftZ!, redo);
  }

  void _removeKeybindings() {
    if (_ctrlZ != null) Keybinder.remove(_ctrlZ!);
    if (_ctrlY != null) Keybinder.remove(_ctrlY!);
    if (_ctrlShiftZ != null) Keybinder.remove(_ctrlShiftZ!);
  }

  /// Creates pages until the given page index exists,
  /// plus an extra blank page
  void createPage(int pageIndex) {
    while (pageIndex >= coreInfo.pages.length - 1) {
      final page = EditorPage();
      coreInfo.pages.add(page);
      listenToQuillChanges(page.quill, coreInfo.pages.length - 1);
    }
  }

  void removeExcessPages() {
    bool removedAPage = false;

    // remove excess pages if all pages >= this one are empty
    for (int i = coreInfo.pages.length - 1; i >= 1; --i) {
      final thisPage = coreInfo.pages[i];
      final prevPage = coreInfo.pages[i - 1];
      if (thisPage.isEmpty && prevPage.isEmpty) {
        final page = coreInfo.pages.removeAt(i);
        page.dispose();
        removedAPage = true;
      } else {
        break;
      }
    }

    if (removedAPage) {
      // scroll to the last page (only if we're below the last page)

      final scrollY = this.scrollY;
      late final topOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length - 1,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );
      final bottomOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length,
        pages: coreInfo.pages,
        screenWidth: MediaQuery.sizeOf(context).width,
      );

      if (scrollY < bottomOfLastPage) {
        _transformationController.value = Matrix4.translationValues(
          0,
          // Slight upwards offset so that the page is not flush with the top of the screen
          topOfLastPage + 50,
          0,
        );
      }
    }
  }

  void undo([EditorHistoryItem? item]) {
    if (item == null) {
      if (!history.canUndo) return;

      // if we disabled redo, re-enable it
      if (!history.canRedo) {
        // no redo is possible, so clear the redo stack
        history.clearRedo();
        // don't disable redoing anymore
        history.canRedo = true;
      }

      item = history.undo();
    }

    setState(() {
      switch (item!.type) {
        case .draw:
          for (final stroke in item.strokes) {
            coreInfo.pages[stroke.pageIndex].strokes.remove(stroke);
          }
          for (final image in item.images) {
            coreInfo.pages[image.pageIndex].images.remove(image);
          }
          removeExcessPages();

        case .erase:
          for (final stroke in item.strokes) {
            createPage(stroke.pageIndex);
            coreInfo.pages[stroke.pageIndex].insertStroke(stroke);
          }
          for (final image in item.images) {
            createPage(image.pageIndex);
            coreInfo.pages[image.pageIndex].images.add(image);
            image.newImage = true;
          }

        case .deletePage:
          // make sure we already have a (blank/otherwise) page at this index
          createPage(item.pageIndex - 1);

          // insert the page at the correct index
          coreInfo.pages.insert(item.pageIndex, item.page!);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex + 1; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

        case .insertPage:
          // remove the page at the given index
          coreInfo.pages.removeAt(item.pageIndex);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

        case .move:
          for (final stroke in item.strokes) {
            stroke.shift(Offset(-item.offset!.left, -item.offset!.top));
          }
          final select = Select.currentSelect;
          if (select.doneSelecting) {
            select.selectResult.path = select.selectResult.path.shift(
              Offset(-item.offset!.left, -item.offset!.top),
            );
          }
          for (final image in item.images) {
            image.dstRect = .fromLTRB(
              image.dstRect.left - item.offset!.left,
              image.dstRect.top - item.offset!.top,
              image.dstRect.right - item.offset!.right,
              image.dstRect.bottom - item.offset!.bottom,
            );
          }

        case .quillChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.undo();

        case .quillUndoneChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.redo();

        case .changeColor:
          for (final stroke in item.strokes) {
            stroke.color = item.colorChange![stroke]!.previous;
          }

        case .backgroundPattern:
          coreInfo.backgroundPattern = item.backgroundPatternChange!.previous;
      }

      if (item.type != .move) {
        Select.currentSelect.unselect();
      }
    });

    autosaveAfterDelay();
  }

  void redo() {
    if (!history.canRedo) return;
    final item = history.redo();

    switch (item.type) {
      case .draw:
        undo(item.copyWith(type: .erase));
      case .erase:
        undo(item.copyWith(type: .draw));
      case .deletePage:
        undo(item.copyWith(type: .insertPage));
      case .insertPage:
        undo(item.copyWith(type: .deletePage));
      case .move:
        undo(
          item.copyWith(
            offset: .fromLTRB(
              -item.offset!.left,
              -item.offset!.top,
              -item.offset!.right,
              -item.offset!.bottom,
            ),
          ),
        );
      case .quillChange:
        undo(item.copyWith(type: .quillUndoneChange));
      case .quillUndoneChange: // this will never happen
        throw Exception('history should not contain quillUndoneChange items');
      case .changeColor:
        undo(
          item.copyWith(
            colorChange: item.colorChange!.map(
              (key, value) => MapEntry(key, value.reverse()),
            ),
          ),
        );
      case .backgroundPattern:
        undo(
          item.copyWith(
            backgroundPatternChange: item.backgroundPatternChange!.reverse(),
          ),
        );
    }
  }

  int? onWhichPageIsFocalPoint(Offset focalPoint) {
    for (int i = 0; i < coreInfo.pages.length; ++i) {
      if (coreInfo.pages[i].renderBox == null) continue;
      final pageBounds = Offset.zero & coreInfo.pages[i].size;
      if (pageBounds.contains(
        coreInfo.pages[i].renderBox!.globalToLocal(focalPoint),
      ))
        return i;
    }
    return null;
  }

  ({int pageIndex, Offset pagePosition})? _pagePositionForGlobal(
    Offset globalPosition,
  ) {
    final pageIndex = onWhichPageIsFocalPoint(globalPosition);
    if (pageIndex == null) return null;

    final renderBox = coreInfo.pages[pageIndex].renderBox;
    if (renderBox == null) return null;

    return (
      pageIndex: pageIndex,
      pagePosition: renderBox.globalToLocal(globalPosition),
    );
  }

  void onStylusHover(PointerEvent event) {
    final sample = StylusSample.fromPointerEvent(event);
    _recordPeripheralDebugData(
      source: 'flutter hover',
      active: true,
      sample: sample,
      globalPosition: event.position,
      hoverDistance: event.distance,
      hoverDistanceMax: event.distanceMax,
    );

    if (Pen.advancedSettingsOpen.value ||
        !stows.applePencilTipPreview.value ||
        coreInfo.readOnly) {
      clearStylusHoverPreview();
      return;
    }

    _setStylusHoverPreview(
      globalPosition: event.position,
      opacity: StylusHoverPreview.opacityFromDistance(
        distance: event.distance,
        distanceMax: event.distanceMax,
      ),
      invertedStylus: event.kind == PointerDeviceKind.invertedStylus,
      directionAngle: event.orientation,
    );
  }

  void _handleApplePencilHover(ApplePencilHoverEvent event) {
    final sample = StylusSample(
      kind: PointerDeviceKind.stylus,
      altitudeAngle: event.altitudeAngle,
      azimuthAngle: event.azimuthAngle,
      rollAngle: event.rollAngle,
    );
    _recordPeripheralDebugData(
      source: 'native hover',
      active: event.isActive,
      sample: sample,
      globalPosition: event.position,
      hoverDistance: event.zOffset,
      hoverDistanceMax: event.zOffset == null ? null : 1,
    );

    if (!event.isActive) {
      clearStylusHoverPreview();
      return;
    }

    if (Pen.advancedSettingsOpen.value ||
        !stows.applePencilTipPreview.value ||
        coreInfo.readOnly) {
      clearStylusHoverPreview();
      return;
    }

    final zOffset = event.zOffset;
    _setStylusHoverPreview(
      globalPosition: event.position,
      opacity: zOffset == null
          ? 0.45
          : StylusHoverPreview.opacityFromDistance(
              distance: zOffset.clamp(0.0, 1.0).toDouble(),
              distanceMax: 1,
            ),
      directionAngle:
          StylusPose.canvasAngleFromNativeRoll(event.rollAngle) ??
          event.azimuthAngle,
    );
  }

  void _handleApplePencilTelemetry(ApplePencilTelemetryEvent event) {
    _recordTelemetryDebugData(event);

    if (!event.isActive) {
      updatePointerData(const StylusSample(kind: PointerDeviceKind.stylus));
      return;
    }

    updatePointerData(event.sample.toStylusSample());
    _appendNativeTelemetryToCurrentStroke(event);
  }

  void _appendNativeTelemetryToCurrentStroke(ApplePencilTelemetryEvent event) {
    if (dragPageIndex == null) return;
    if (currentTool is! Pen) return;

    final page = coreInfo.pages[dragPageIndex!];
    final renderBox = page.renderBox;
    if (renderBox == null) return;

    var didAppend = false;
    for (final sample in event.realSamples) {
      final timestamp = sample.timestamp;
      if (timestamp != null &&
          _lastNativeTelemetryTimestamp != null &&
          timestamp <= _lastNativeTelemetryTimestamp!) {
        continue;
      }

      final stylusSample = sample.toStylusSample();
      final hadCurrentStroke = Pen.currentStroke != null;
      final completedStrokeSegment = (currentTool as Pen).onDragUpdate(
        renderBox.globalToLocal(sample.precisePosition),
        stylusSample,
      );
      if (completedStrokeSegment != null) {
        _insertCompletedPenStrokeSegment(completedStrokeSegment, page);
      }
      if (!hadCurrentStroke && Pen.currentStroke != null) {
        setState(() {});
      }
      _lastNativeTelemetryTimestamp = timestamp;
      didAppend = true;
    }

    if (!didAppend) return;

    _nativeTelemetryDrawingActive = true;
    page.redrawStrokes();
  }

  void _recordTelemetryDebugData(ApplePencilTelemetryEvent event) {
    final sample = event.sample;
    _recordPeripheralDebugData(
      source: 'native touch',
      active: event.isActive,
      sample: sample.toStylusSample(),
      globalPosition: sample.precisePosition,
      force: sample.force,
      maximumPossibleForce: sample.maximumPossibleForce,
      majorRadius: sample.majorRadius,
      coalescedCount: event.coalescedSamples.length,
      predictedCount: event.predictedSamples.length,
    );
  }

  void _recordPeripheralDebugData({
    required String source,
    required bool active,
    StylusSample? sample,
    Offset? globalPosition,
    Offset? pagePosition,
    int? pageIndex,
    double? force,
    double? maximumPossibleForce,
    double? hoverDistance,
    double? hoverDistanceMax,
    double? majorRadius,
    int? coalescedCount,
    int? predictedCount,
  }) {
    if (!stows.peripheralDebugDataWindow.value) return;

    final pageLookup = globalPosition == null
        ? null
        : _pagePositionForGlobal(globalPosition);
    final effectivePressure = currentTool is Pen
        ? (currentTool as Pen).effectivePressureForSample(sample)
        : null;

    _peripheralDebugData.value = PeripheralDebugData(
      source: source,
      updatedAt: DateTime.now(),
      active: active,
      kind: sample?.kind ?? currentPointerKind,
      pageIndex: pageIndex ?? pageLookup?.pageIndex,
      globalPosition: globalPosition,
      pagePosition: pagePosition ?? pageLookup?.pagePosition,
      rawPressure: sample?.pressure,
      effectivePressure: effectivePressure,
      force: force,
      maximumPossibleForce: maximumPossibleForce,
      hoverDistance: hoverDistance,
      hoverDistanceMax: hoverDistanceMax,
      tilt: sample?.tilt,
      orientation: sample?.orientation,
      altitudeAngle: sample?.altitudeAngle,
      azimuthAngle: sample?.azimuthAngle,
      rollAngle: sample?.rollAngle,
      majorRadius: majorRadius,
      timestamp: sample?.timestamp,
      sourceFlags: sample?.sourceFlags,
      coalescedCount: coalescedCount,
      predictedCount: predictedCount,
    );
  }

  void _setStylusHoverPreview({
    required Offset globalPosition,
    required double opacity,
    bool invertedStylus = false,
    double? directionAngle,
  }) {
    final pageIndex = onWhichPageIsFocalPoint(globalPosition);
    if (pageIndex == null) {
      clearStylusHoverPreview();
      return;
    }

    final renderBox = coreInfo.pages[pageIndex].renderBox;
    if (renderBox == null) {
      clearStylusHoverPreview();
      return;
    }

    final preview = _stylusHoverPreviewForTool(
      pageIndex: pageIndex,
      position: renderBox.globalToLocal(globalPosition),
      opacity: opacity,
      invertedStylus: invertedStylus,
      directionAngle: directionAngle,
    );
    if (preview == null) {
      clearStylusHoverPreview();
      return;
    }

    if (_stylusHoverPreview == preview) return;
    setState(() => _stylusHoverPreview = preview);
  }

  void clearStylusHoverPreview() {
    if (_stylusHoverPreview == null) return;
    if (!mounted) {
      _stylusHoverPreview = null;
      return;
    }

    setState(() => _stylusHoverPreview = null);
  }

  StylusHoverPreview? _stylusHoverPreviewForTool({
    required int pageIndex,
    required Offset position,
    required double opacity,
    bool invertedStylus = false,
    double? directionAngle,
  }) {
    final tool = invertedStylus ? Eraser() : currentTool;

    if (tool is Eraser) {
      return StylusHoverPreview(
        pageIndex: pageIndex,
        position: position,
        radius: tool.size,
        color: Colors.black,
        opacity: opacity,
        kind: StylusHoverPreviewKind.eraser,
        invertedStylus: invertedStylus,
        directionAngle: null,
      );
    }

    if (tool is Pen) {
      return StylusHoverPreview(
        pageIndex: pageIndex,
        position: position,
        radius: tool.options.size / 2,
        color: tool.color,
        opacity: opacity,
        kind: StylusHoverPreviewKind.drawing,
        invertedStylus: invertedStylus,
        directionAngle: directionAngle,
      );
    }

    return null;
  }

  /// The position of the previous draw gesture event.
  /// Used to move a selection.
  Offset previousPosition = .zero;

  /// The total offset of the current move gesture.
  /// Used to record a move in the history.
  Offset moveOffset = .zero;

  var isHovering = true;
  int? dragPageIndex;
  PointerDeviceKind? currentPointerKind;
  StylusSample? currentStylusSample;
  final _completedPenStrokeSegments = <Stroke>[];
  var _nativeTelemetryDrawingActive = false;
  double? _lastNativeTelemetryTimestamp;
  DateTime? _lastWritingStrokeEndedAt;
  var _suppressAutoStraightenForCurrentStroke = false;

  bool isDrawGesture(ScaleStartDetails details) {
    if (coreInfo.readOnly) return false;
    clearStylusHoverPreview();

    CanvasImage.activeListener
        .notifyListenersPlease(); // un-select active image

    _lastSeenPointerCountTimer?.cancel();
    if (lastSeenPointerCount >= 2) {
      // was a zoom gesture, ignore
      lastSeenPointerCount = lastSeenPointerCount;
      return false;
    } else if (details.pointerCount >= 2) {
      // is a zoom gesture, remove accidental stroke
      if (lastSeenPointerCount == 1 &&
          stows.editorFingerDrawing.value &&
          (currentTool is Pen || currentTool is Eraser)) {
        final item = history.removeAccidentalStroke();
        if (item != null) undo(item);
      }
      lastSeenPointerCount = details.pointerCount;
      return false;
    } else {
      // is a stroke
      lastSeenPointerCount = details.pointerCount;
    }

    dragPageIndex = onWhichPageIsFocalPoint(details.focalPoint);
    if (dragPageIndex == null) return false;

    if (currentTool == Tool.textEditing) {
      return false;
    } else if (stows.editorFingerDrawing.value ||
        currentPointerKind == PointerDeviceKind.stylus ||
        currentPointerKind == PointerDeviceKind.invertedStylus ||
        currentStylusSample?.isStylus == true) {
      return true;
    } else {
      log.fine('Non-stylus found, rejected stroke');
      return false;
    }
  }

  void onDrawStart(ScaleStartDetails details) {
    clearStylusHoverPreview();
    _completedPenStrokeSegments.clear();
    _nativeTelemetryDrawingActive = false;
    _lastNativeTelemetryTimestamp = null;
    _suppressAutoStraightenForCurrentStroke =
        currentTool is Pen &&
        currentTool is! ShapePen &&
        shouldSuppressAutoStraightenForContinuousWriting(
          previousStrokeEndedAt: _lastWritingStrokeEndedAt,
          currentStrokeStartedAt: DateTime.now(),
          window: Duration(
            milliseconds: stows.continuousWritingAutoStraightenWindowMs.value,
          ),
        );

    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    _recordPeripheralDebugData(
      source: 'draw start',
      active: true,
      sample: currentStylusSample,
      globalPosition: details.focalPoint,
      pageIndex: dragPageIndex,
      pagePosition: position,
    );
    history.canRedo = false;

    if (currentTool is Pen) {
      (currentTool as Pen).onDragStart(
        position,
        page,
        dragPageIndex!,
        currentStylusSample,
      );
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
      }
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex! &&
          select.selectResult.path.contains(position)) {
        // drag selection in onDrawUpdate
      } else {
        select.onDragStart(position, dragPageIndex!);
        history.canRedo = true; // selection doesn't affect history
      }
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragStart(position, page, dragPageIndex!);
    }

    previousPosition = position;
    moveOffset = .zero;

    if (currentTool is! Select) {
      Select.currentSelect.unselect();
    }

    // setState to let canvas know about currentStroke
    setState(() {});
  }

  void onDrawUpdate(ScaleUpdateDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    _recordPeripheralDebugData(
      source: _nativeTelemetryDrawingActive ? 'native touch' : 'draw update',
      active: true,
      sample: currentStylusSample,
      globalPosition: details.focalPoint,
      pageIndex: dragPageIndex,
      pagePosition: position,
    );
    final offset = position - previousPosition;

    if (currentTool is Pen) {
      if (!_nativeTelemetryDrawingActive) {
        final hadCurrentStroke = Pen.currentStroke != null;
        final completedStrokeSegment = (currentTool as Pen).onDragUpdate(
          position,
          currentStylusSample,
        );
        if (completedStrokeSegment != null) {
          _insertCompletedPenStrokeSegment(completedStrokeSegment, page);
        }
        if (!hadCurrentStroke && Pen.currentStroke != null) {
          setState(() {});
        }
      }
      page.redrawStrokes();
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
      }
      page.redrawStrokes();
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.doneSelecting) {
        for (final stroke in select.selectResult.strokes) {
          stroke.shift(offset);
        }
        for (final image in select.selectResult.images) {
          image.dstRect = image.dstRect.shift(offset);
        }
        select.selectResult.path = select.selectResult.path.shift(offset);
      } else {
        select.onDragUpdate(position);
      }
      page.redrawStrokes();
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragUpdate(position);
      page.redrawStrokes();
    }
    previousPosition = position;
    moveOffset += offset;
  }

  void _insertCompletedPenStrokeSegment(Stroke stroke, EditorPage page) {
    if (stroke.isEmpty) return;

    _prepareCompletedPenStroke(stroke);
    createPage(stroke.pageIndex);
    page.insertStroke(stroke);
    _completedPenStrokeSegments.add(stroke);
  }

  void _prepareCompletedPenStroke(Stroke stroke) {
    if (stows.autoStraightenLines.value &&
        currentTool is! ShapePen &&
        !_suppressAutoStraightenForCurrentStroke &&
        stroke.isStraightLine()) {
      stroke.convertToLine();
    }
  }

  void onDrawEnd(ScaleEndDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    bool shouldSave = true;
    var didFinishWritingStroke = false;
    setState(() {
      if (currentTool is Pen) {
        final newStrokes = [..._completedPenStrokeSegments];
        final newStroke = (currentTool as Pen).onDragEnd();
        if (newStroke != null && !newStroke.isEmpty) {
          _prepareCompletedPenStroke(newStroke);
          createPage(newStroke.pageIndex);
          page.insertStroke(newStroke);
          newStrokes.add(newStroke);
        }

        if (newStrokes.isEmpty) return;

        history.recordChange(
          EditorHistoryItem(
            type: .draw,
            pageIndex: dragPageIndex!,
            strokes: newStrokes,
            images: [],
          ),
        );
        didFinishWritingStroke = currentTool is! ShapePen;
      } else if (currentTool is Eraser) {
        final erased = (currentTool as Eraser).onDragEnd();
        if (stylusButtonWasPressed || stows.disableEraserAfterUse.value) {
          // restore previous tool
          stylusButtonWasPressed = false;
          currentTool = _lastNonEraserTool;
        }
        if (erased.isEmpty) return;
        history.recordChange(
          EditorHistoryItem(
            type: .erase,
            pageIndex: dragPageIndex!,
            strokes: erased,
            images: [],
          ),
        );
      } else if (currentTool is Select) {
        if (moveOffset == .zero) return;
        final select = currentTool as Select;
        if (select.doneSelecting) {
          history.recordChange(
            EditorHistoryItem(
              type: .move,
              pageIndex: dragPageIndex!,
              strokes: select.selectResult.strokes,
              images: select.selectResult.images,
              offset: .fromLTRB(
                moveOffset.dx,
                moveOffset.dy,
                moveOffset.dx,
                moveOffset.dy,
              ),
            ),
          );
        } else {
          shouldSave = false;
          select.onDragEnd(page.strokes, page.images);

          if (select.selectResult.isEmpty) {
            Select.currentSelect.unselect();
          }
        }
      } else if (currentTool is LaserPointer) {
        shouldSave = false;
        final newStroke = (currentTool as LaserPointer).onDragEnd(
          page.redrawStrokes,
          (Stroke stroke) {
            page.laserStrokes.remove(stroke);
          },
        );
        if (newStroke != null) page.laserStrokes.add(newStroke);
      }
    });

    if (shouldSave) autosaveAfterDelay();
    if (didFinishWritingStroke) {
      _lastWritingStrokeEndedAt = DateTime.now();
    }
    _completedPenStrokeSegments.clear();
    _suppressAutoStraightenForCurrentStroke = false;
    _nativeTelemetryDrawingActive = false;
    _lastNativeTelemetryTimestamp = null;
    _recordPeripheralDebugData(
      source: 'draw end',
      active: false,
      sample: currentStylusSample,
    );
  }

  void onInteractionEnd(ScaleEndDetails details) {
    // reset after 1ms to keep track of the same gesture only
    _lastSeenPointerCountTimer?.cancel();
    _lastSeenPointerCountTimer = Timer(const Duration(milliseconds: 10), () {
      lastSeenPointerCount = 0;
    });
  }

  void updatePointerData(StylusSample sample) {
    currentPointerKind = sample.kind;
    currentStylusSample = sample.isStylus ? sample : null;
    if (!sample.isStylus) {
      _recordPeripheralDebugData(
        source: 'pointer ended',
        active: false,
        sample: sample,
      );
    }
  }

  void onHovering() {
    isHovering = true;
  }

  void onHoveringEnd() {
    isHovering = false;
  }

  void onStylusButtonChanged(bool buttonIsPressed) {
    stylusButtonWasPressed |= buttonIsPressed;

    if (!isHovering) return;
    if (buttonIsPressed) {
      // button pressed while hovering, switch to Eraser
      if (currentTool is! Eraser) {
        currentTool = Eraser();
      }
    } else {
      // button was released while hovering, switch back to non-Eraser
      if (currentTool is Eraser) {
        currentTool = _lastNonEraserTool;
      }
    }

    if (mounted) setState(() {});
  }

  void _handleApplePencilInteraction(ApplePencilInteractionEvent event) {
    if (coreInfo.readOnly) return;

    final preference = switch (event.gesture) {
      ApplePencilHardwareGesture.doubleTap =>
        stows.applePencilDoubleTapAction.value,
      ApplePencilHardwareGesture.squeeze =>
        stows.applePencilSqueezeAction.value,
    };
    final action = preference.resolve(event);
    if (action == ApplePencilAction.disabled) return;

    switch (event.gesture) {
      case ApplePencilHardwareGesture.doubleTap:
        _handleApplePencilDoubleTap(event, action);
      case ApplePencilHardwareGesture.squeeze:
        _handleApplePencilSqueeze(event, action);
    }
  }

  void _handleApplePencilDoubleTap(
    ApplePencilInteractionEvent event,
    ApplePencilAction action,
  ) {
    if (event.phase != ApplePencilInteractionPhase.ended) return;

    _runApplePencilAction(action);
  }

  void _handleApplePencilSqueeze(
    ApplePencilInteractionEvent event,
    ApplePencilAction action,
  ) {
    switch (event.phase) {
      case ApplePencilInteractionPhase.began:
        if (action == ApplePencilAction.toggleEraser) {
          _beginApplePencilSqueezeEraser();
          return;
        }
        _runApplePencilAction(action);
      case ApplePencilInteractionPhase.changed:
        return;
      case ApplePencilInteractionPhase.ended:
      case ApplePencilInteractionPhase.cancelled:
        _endApplePencilSqueezeEraser();
    }
  }

  void _beginApplePencilSqueezeEraser() {
    if (!stows.disableEraserAfterUse.value) {
      _setTool(Eraser());
      return;
    }

    if (_applePencilSqueezeEraserActive) return;
    if (currentTool is Eraser) return;

    _applePencilSqueezeRestoreTool = currentTool;
    _applePencilSqueezeEraserActive = true;
    currentTool = Eraser();
    if (mounted) setState(() {});
  }

  void _endApplePencilSqueezeEraser() {
    if (!_applePencilSqueezeEraserActive) return;

    final restoreTool = _applePencilSqueezeRestoreTool;
    _applePencilSqueezeRestoreTool = null;
    _applePencilSqueezeEraserActive = false;

    if (restoreTool == null) return;
    if (currentTool is! Eraser) return;

    currentTool = restoreTool;
    if (mounted) setState(() {});
  }

  void _runApplePencilAction(ApplePencilAction action) {
    switch (action) {
      case ApplePencilAction.system:
      case ApplePencilAction.disabled:
        return;
      case ApplePencilAction.toggleEraser:
        _setTool(Eraser());
      case ApplePencilAction.switchPreviousTool:
        final previousTool = _previousNonTransientTool;
        if (previousTool == null || previousTool == currentTool) return;
        _setTool(previousTool);
      case ApplePencilAction.showColorPalette:
        _revealToolbar();
        _toolbarKey.currentState?.toggleColorOptions();
      case ApplePencilAction.showInkAttributes:
        _revealToolbar();
        _toolbarKey.currentState?.toggleCurrentToolOptions();
      case ApplePencilAction.showToolPalette:
        _revealToolbar();
        _toolbarKey.currentState?.toggleCurrentToolOptions();
      case ApplePencilAction.runSystemShortcut:
        log.info('Apple Pencil system shortcut action is not supported');
    }
  }

  void _revealToolbar() {
    if (!DynamicMaterialApp.isFullscreen) return;
    if (stows.editorToolbarShowInFullscreen.value) return;

    DynamicMaterialApp.setFullscreen(false, updateSystem: true);
  }

  void _setTool(Tool tool) {
    if (tool is Eraser && currentTool is Eraser) {
      // setTool(Eraser) is a special case to toggle the eraser on/off
      tool = _lastNonEraserTool;
    }

    currentTool = tool;

    if (tool is Highlighter) {
      Highlighter.currentHighlighter = tool;
    } else if (tool is Pencil) {
      Pencil.currentPencil = tool;
    } else if (tool is Pen) {
      Pen.currentPen = tool;
    }

    if (mounted) setState(() {});
  }

  void onMoveImage(EditorImage image, Rect offset) {
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
        offset: offset,
      ),
    );
    // setState to update undo button
    setState(() {});
    autosaveAfterDelay();
  }

  void onDeleteImage(EditorImage image) {
    history.recordChange(
      EditorHistoryItem(
        type: .erase,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
      ),
    );
    setState(() {
      coreInfo.pages[image.pageIndex].images.remove(image);
    });
    autosaveAfterDelay();
  }

  void listenToQuillChanges(QuillStruct quill, int pageIndex) {
    quill.changeSubscription?.cancel();
    quill.changeSubscription = quill.controller.changes.listen((event) {
      final undoRedoButtonsNeedUpdating = !history.canUndo || history.canRedo;
      _addQuillChangeToHistory(
        quill: quill,
        pageIndex: pageIndex,
        event: event,
      );
      createPage(pageIndex); // create empty last page
      if (undoRedoButtonsNeedUpdating) {
        setState(() {});
      }
      autosaveAfterDelay();
    });
    quill.focusNode.addListener(_onQuillFocusChange);
  }

  void _onQuillFocusChange() {
    for (final page in coreInfo.pages) {
      if (!page.quill.focusNode.hasFocus) continue;
      quillFocus.value = page.quill;
    }
  }

  void _addQuillChangeToHistory({
    required QuillStruct quill,
    required int pageIndex,
    required flutter_quill.DocChange event,
  }) {
    final eventWasUndo = quill.controller.hasRedo;
    if (eventWasUndo) return;

    // the change subscription sometimes fires multiple times for the same change
    // so compare the "before" of each change to merge them
    if (history.canUndo && !history.canRedo) {
      final lastChange = history.peekUndo();
      if (lastChange.type == .quillChange &&
          lastChange.pageIndex == pageIndex &&
          lastChange.quillChange!.before == event.before) {
        history.undo(); // remove the last change, to be replaced
      }
    }

    history.recordChange(
      EditorHistoryItem(
        type: .quillChange,
        pageIndex: pageIndex,
        strokes: const [],
        images: const [],
        quillChange: event,
      ),
    );
  }

  void _refreshCurrentNote() async {
    if (coreInfo.readOnlyReason != .watchingServer) return;
    if (!stows.loggedIn) return;

    final relativeFilePath = coreInfo.filePath;
    assert(relativeFilePath.isNotEmpty, 'Cannot refresh unnamed file');
    final syncFile = await SaberSyncFile.relative(
      relativeFilePath + Editor.extension,
    );

    final bestFile = await SaberSyncInterface.getBestFile(
      syncFile,
      onLocalFileNotFound: .local,
      onEqualFiles: .local,
      preferCache: false,
    );
    if (bestFile != .remote) return;

    late final StreamSubscription<SaberSyncFile> subscription;
    void listener(SaberSyncFile transferred) {
      if (transferred != syncFile) return;
      subscription.cancel();
      _loadCoreInfo(
        relativeFilePath,
      ).then((_) => coreInfo.readOnlyReason = .watchingServer);
    }

    subscription = syncer.downloader.transferStream.listen(listener);

    await syncer.downloader.enqueue(syncFile: syncFile);
    syncer.downloader.bringToFront(syncFile);
  }

  void autosaveAfterDelay() {
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    late final void Function() callback;

    void startTimer() {
      _delayedSaveTimer?.cancel();
      if (stows.autosaveDelay.value < 0) return;
      _delayedSaveTimer = Timer(
        Duration(milliseconds: stows.autosaveDelay.value),
        callback,
      );
    }

    callback = () {
      if (Pen.currentStroke != null || _completedPenStrokeSegments.isNotEmpty) {
        // don't save yet if the pen is currently drawing
        startTimer();
        return;
      }
      saveToFile();
    };

    savingState.value = .waitingToSave;
    startTimer();
  }

  void cancelAutosaveAndMarkSaved() {
    _delayedSaveTimer?.cancel();
    savingState.value = .saved;
    history.markLastChangeAsSaved();
  }

  Future<void> saveToFile() async {
    if (coreInfo.readOnly) return;

    switch (savingState.value) {
      case .saved:
        // avoid saving if nothing has changed
        return;
      case .saving:
        // avoid saving if already saving
        log.warning('saveToFile() called while already saving');
        return;
      case .waitingToSave:
        // continue
        _delayedSaveTimer?.cancel();
        savingState.value = .saving;
    }
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    await _renameFileNow();

    final filePath = coreInfo.filePath + Editor.extension;
    final Uint8List bson;
    final OrderedAssetCache assets;
    coreInfo.assetCache.allowRemovingAssets = false;
    try {
      (bson, assets) = coreInfo.saveToBinary(
        currentPageIndex: currentPageIndex,
      );
    } finally {
      coreInfo.assetCache.allowRemovingAssets = true;
    }
    try {
      await Future.wait([
        FileManager.writeFile(filePath, bson, awaitWrite: true),
        for (int i = 0; i < assets.length; ++i)
          assets
              .getBytes(i)
              .then(
                (bytes) => FileManager.writeFile(
                  '$filePath.$i',
                  bytes,
                  awaitWrite: true,
                ),
              ),
        FileManager.removeUnusedAssets(filePath, numAssets: assets.length),
      ]);
      savingState.value = .saved;
      history.markLastChangeAsSaved();
    } catch (e, st) {
      log.severe('Failed to save file: $e', e, st);
      savingState.value = .waitingToSave;
      if (kDebugMode) rethrow;
      return;
    }

    if (!mounted) return;
    final page = coreInfo.pages.first;
    final previewHeight = page.previewHeight(lineHeight: coreInfo.lineHeight);
    final thumbnailSize = Size(720, 720 * previewHeight / page.size.width);
    final thumbnail = await EditorExporter.screenshotPage(
      coreInfo: coreInfo,
      pageIndex: 0,
      rasterizeAllStrokes: true,
      targetSize: thumbnailSize,
      cropHeight: previewHeight,
      pixelRatio: 1,
    );
    final thumbnailPng = await thumbnail.toByteData(format: .png);
    thumbnail.dispose();
    await FileManager.writeFile(
      // Note that this ends with .sbn2.p
      '$filePath.p',
      thumbnailPng!.buffer.asUint8List(),
      awaitWrite: true,
    );
  }

  late final _filenameFormKey = GlobalKey<FormState>();
  late final filenameTextEditingController = TextEditingController();
  Timer? _renameTimer;
  void renameFile([String? _]) {
    _renameTimer?.cancel();
    _renameTimer = Timer(const Duration(seconds: 5), _renameFileNow);
  }

  Future<void> _renameFileNow() async {
    final newName = filenameTextEditingController.text.trim();
    if (newName == coreInfo.fileName) return;

    if (_filenameFormKey.currentState?.validate() ??
        _validateFilenameTextField(newName) == null) {
      coreInfo.filePath = await FileManager.moveFile(
        coreInfo.filePath + Editor.extension,
        newName.trim() + Editor.extension,
      );
      coreInfo.filePath = coreInfo.filePath.substring(
        0,
        coreInfo.filePath.lastIndexOf(Editor.extension),
      );
      needsNaming = false;
    }

    final actualName = coreInfo.fileName;
    if (actualName != newName) {
      // update text field if renamed differently
      filenameTextEditingController.value = filenameTextEditingController.value
          .copyWith(
            text: actualName,
            selection: TextSelection.fromPosition(
              TextPosition(offset: actualName.length),
            ),
            composing: TextRange.empty,
          );
    }
  }

  String? _validateFilenameTextField(String? newName) {
    if (newName == null) return null;
    return FileManager.validateFilename(newName);
  }

  void updateColorBar(Color color) {
    if (stows.recentColorsDontSavePresets.value) {
      if (ColorBar.colorPresets.any(
        (colorPreset) => colorPreset.color == color,
      )) {
        return;
      }
    }

    final newColorString = color.toARGB32().toString();

    // migrate from old pref format
    if (stows.recentColorsChronological.value.length !=
        stows.recentColorsPositioned.value.length) {
      log.info(
        'MIGRATING recentColors: ${stows.recentColorsChronological.value.length} vs ${stows.recentColorsPositioned.value.length}',
      );
      stows.recentColorsChronological.value = List.of(
        stows.recentColorsPositioned.value,
      );
    }

    if (stows.pinnedColors.value.contains(newColorString)) {
      // do nothing, color is already pinned
    } else if (stows.recentColorsPositioned.value.contains(newColorString)) {
      // if it's already a recent color, move it to the top
      stows.recentColorsChronological.value.remove(newColorString);
      stows.recentColorsChronological.value.add(newColorString);
      stows.recentColorsChronological.notifyListeners();
    } else {
      if (stows.recentColorsPositioned.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace the oldest color with the new one
        final removedColorString = stows.recentColorsChronological.value
            .removeAt(0);
        stows.recentColorsChronological.value.add(newColorString);
        final int removedColorPosition = stows.recentColorsPositioned.value
            .indexOf(removedColorString);
        stows.recentColorsPositioned.value[removedColorPosition] =
            newColorString;
      } else {
        // if not full, add the new color to the end
        stows.recentColorsChronological.value.add(newColorString);
        stows.recentColorsPositioned.value.insert(0, newColorString);
      }
      stows.recentColorsChronological.notifyListeners();
      stows.recentColorsPositioned.notifyListeners();
    }
  }

  /// Prompts the user to pick photos from their device.
  /// Returns the number of photos picked.
  ///
  /// If [photoInfos] is provided, it will be used instead of the file picker.
  Future<int> _pickPhotos([List<_PhotoInfo>? photoInfos]) async {
    if (coreInfo.readOnly) return 0;

    final currentPageIndex = this.currentPageIndex;

    photoInfos ??= await _pickPhotosWithFilePicker();
    if (photoInfos.isEmpty) return 0;

    // use the Select tool so that the user can move the new image
    currentTool = Select.currentSelect;

    final images = [
      for (final _PhotoInfo photoInfo in photoInfos)
        if (photoInfo.extension == '.svg')
          SvgEditorImage(
            id: coreInfo.nextImageId++,
            svgString: utf8.decode(photoInfo.bytes),
            svgFile: null,
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          )
        else
          PngEditorImage(
            id: coreInfo.nextImageId++,
            extension: photoInfo.extension,
            imageProvider: MemoryImage(photoInfo.bytes),
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          ),
    ];

    history.recordChange(
      EditorHistoryItem(
        type: .draw,
        pageIndex: currentPageIndex,
        strokes: [],
        images: images,
      ),
    );
    createPage(currentPageIndex);
    coreInfo.pages[currentPageIndex].images.addAll(images);
    autosaveAfterDelay();

    return images.length;
  }

  Future<List<_PhotoInfo>> _pickPhotosWithFilePicker() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      // Taken from
      // https://github.com/brendan-duncan/image/blob/main/doc/formats.md
      // (plus .svg)
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'tiff',
        'bmp',
        'tga',
        'ico',
        'pvrtc',
        'svg',
        'webp',
        'psd',
        'exr',
      ],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];

    return [
      for (final PlatformFile file in result.files)
        if (file.bytes != null && file.extension != null)
          (bytes: file.bytes!, extension: '.${file.extension}'),
    ];
  }

  /// Prompts the user to pick a PDF to import.
  /// Returns whether a PDF was picked.
  Future<bool> importPdf() async {
    if (coreInfo.readOnly) return false;
    if (!Editor.canRasterPdf) return false;

    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return false;

    final PlatformFile file = result.files.single;
    return importPdfFromFilePath(file.path!);
  }

  Future<bool> importPdfFromFilePath(String path) async {
    final pdfDocument = await coreInfo.assetCache.pdfDocumentCache.load(path);

    final emptyPage = coreInfo.pages.removeLast();
    assert(emptyPage.isEmpty);

    for (final pdfPage in pdfDocument.pages) {
      assert(pdfPage.pageNumber >= 1, 'pdfrx page numbers start at 1');

      // resize to [defaultWidth] to keep pen sizes consistent
      final pageSize = Size(
        EditorPage.defaultWidth,
        EditorPage.defaultWidth * pdfPage.height / pdfPage.width,
      );

      final page = EditorPage(
        size: pageSize,
        backgroundImage: PdfEditorImage(
          id: coreInfo.nextImageId++,
          pdfBytes: null,
          pdfFile: File(path),
          pdfPage: pdfPage.pageNumber - 1,
          pageIndex: coreInfo.pages.length,
          pageSize: pageSize,
          naturalSize: pdfPage.size,
          onMoveImage: onMoveImage,
          onDeleteImage: onDeleteImage,
          onMiscChange: autosaveAfterDelay,
          onLoad: () => setState(() {}),
          assetCache: coreInfo.assetCache,
        ),
      );
      coreInfo.pages.add(page);
      // TODO(adil192): Group multiple pages into one atomic change
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: coreInfo.pages.length - 1,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
    }

    coreInfo.pages.add(emptyPage);
    if (mounted) setState(() {});

    autosaveAfterDelay();

    return true;
  }

  Future paste() async {
    /// Maps image formats to their file extension.
    const Map<SimpleFileFormat, String> formats = {
      Formats.jpeg: '.jpeg',
      Formats.png: '.png',
      Formats.gif: '.gif',
      Formats.tiff: '.tiff',
      Formats.bmp: '.bmp',
      Formats.ico: '.ico',
      Formats.svg: '.svg',
      Formats.webp: '.webp',
    };

    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return;

    final List<_PhotoInfo> photoInfos = [];
    final List<ReadProgress> progresses = [];

    for (final format in formats.keys) {
      if (!reader.canProvide(format)) continue;
      final progress = reader.getFile(format, (file) async {
        final stream = file.getStream();
        final List<int> bytes = [];
        await for (final chunk in stream) {
          bytes.addAll(chunk);
        }
        if (bytes.isEmpty) {
          log.warning('Pasted empty file: $file (${formats[format]})');
          return;
        }

        String extension;
        if (file.fileName != null) {
          extension = file.fileName!.substring(file.fileName!.lastIndexOf('.'));
        } else {
          extension = formats[format]!;
        }

        photoInfos.add((
          bytes: Uint8List.fromList(bytes),
          extension: extension,
        ));
      });
      if (progress != null) progresses.add(progress);
    }

    while (progresses.isNotEmpty) {
      progresses.removeWhere((progress) => progress.fraction.value == 1);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _pickPhotos(photoInfos);
  }

  Future exportAsPdf(BuildContext context) async {
    final pdf = await EditorExporter.generatePdf(coreInfo, context);
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.pdf',
      bytes,
      context: context,
    );
  }

  /// Exports the current note as an SBA (Saber Archive) file.
  Future exportAsSba(BuildContext context) async {
    final sba = await coreInfo.saveToSba(currentPageIndex: currentPageIndex);
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.sba',
      sba,
      context: context,
    );
  }

  /// Exports the current page as a PNG image file.
  ///
  /// This captures the canvas natively via [EditorExporter.screenshotPage],
  /// which guarantees the correct background color and omits UI elements
  /// like selection bounds or the text cursor. It computes a dynamic [pixelRatio]
  /// to ensure high quality while averting Out-Of-Memory exceptions on large canvases.
  Future exportAsPng(BuildContext context) async {
    final page = coreInfo.pages[currentPageIndex];

    const maxRasterizableSize = 3000.0;
    var targetPixelRatio = maxRasterizableSize / page.size.longestSide;
    if (targetPixelRatio > 1) targetPixelRatio = 1;

    try {
      final image = await EditorExporter.screenshotPage(
        coreInfo: coreInfo,
        pageIndex: currentPageIndex,
        rasterizeAllStrokes: true,
        pixelRatio: targetPixelRatio,
      );
      final pngBytes = await image.toByteData(format: .png);
      image.dispose();

      if (!context.mounted) return;
      await FileManager.exportFile(
        '${coreInfo.fileName}_page_${currentPageIndex + 1}.png',
        pngBytes!.buffer.asUint8List(),
        isImage: true,
        context: context,
      );
    } catch (e, st) {
      log.severe('Failed to export PNG', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final platform = Theme.of(context).platform;
    final isToolbarVertical =
        stows.editorToolbarAlignment.value == AxisDirection.left ||
        stows.editorToolbarAlignment.value == AxisDirection.right;

    final Widget canvas = CanvasGestureDetector(
      key: _canvasGestureDetectorKey,
      filePath: coreInfo.filePath,
      isDrawGesture: isDrawGesture,
      onInteractionEnd: onInteractionEnd,
      onDrawStart: onDrawStart,
      onDrawUpdate: onDrawUpdate,
      onDrawEnd: onDrawEnd,
      onHovering: onHovering,
      onHoveringEnd: onHoveringEnd,
      onStylusHover: onStylusHover,
      onStylusHoverEnd: clearStylusHoverPreview,
      onStylusButtonChanged: onStylusButtonChanged,
      updatePointerData: updatePointerData,
      undo: undo,
      redo: redo,
      pages: coreInfo.pages,
      initialPageIndex: coreInfo.initialPageIndex,
      pageBuilder: pageBuilder,
      isTextEditing: () => currentTool == Tool.textEditing,
      placeholderPageBuilder: (BuildContext context, int pageIndex) {
        return Canvas(
          path: coreInfo.filePath,
          page: coreInfo.pages[pageIndex],
          pageIndex: 0,
          textEditing: false,
          coreInfo: EditorCoreInfo.placeholder,
          currentStroke: null,
          currentStrokeDetectedShape: null,
          currentSelection: null,
          placeholder: true,
          setAsBackground: null,
          currentTool: currentTool,
          currentScale: double.minPositive,
          stylusHoverPreview: null,
        );
      },
      transformationController: _transformationController,
    );

    final readonlyBanner = ReadOnlyBanner(
      coreInfo.readOnlyReason,
      action: coreInfo.readOnlyReason == .versionTooNew
          ? showVersionTooNewDialog
          : null,
    );

    final Widget toolbar = Collapsible(
      axis: isToolbarVertical
          ? CollapsibleAxis.horizontal
          : CollapsibleAxis.vertical,
      collapsed:
          DynamicMaterialApp.isFullscreen &&
          !stows.editorToolbarShowInFullscreen.value,
      maintainState: true,
      child: SafeArea(
        bottom: stows.editorToolbarAlignment.value != AxisDirection.up,
        child: Toolbar(
          key: _toolbarKey,
          readOnly: coreInfo.readOnly,
          setTool: _setTool,
          currentTool: currentTool,
          duplicateSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) return;

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              const duplicationFeedbackOffset = Offset(25, -25);

              final duplicatedStrokes = strokes.map((stroke) {
                return stroke.copy()..shift(duplicationFeedbackOffset);
              }).toList();

              final duplicatedImages = images.map((image) {
                return image.copy()
                  ..id = coreInfo.nextImageId++
                  ..dstRect.shift(duplicationFeedbackOffset);
              }).toList();

              page.strokes.addAll(duplicatedStrokes);
              page.images.addAll(duplicatedImages);

              select.selectResult = select.selectResult.copyWith(
                strokes: duplicatedStrokes,
                images: duplicatedImages,
                path: select.selectResult.path.shift(duplicationFeedbackOffset),
              );

              history.recordChange(
                EditorHistoryItem(
                  type: .draw,
                  pageIndex: select.selectResult.pageIndex,
                  strokes: duplicatedStrokes,
                  images: duplicatedImages,
                ),
              );
              autosaveAfterDelay();
            });
          },
          deleteSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) {
              return;
            }

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              for (final stroke in strokes) {
                page.strokes.remove(stroke);
              }
              for (final image in images) {
                page.images.remove(image);
              }

              select.unselect();

              history.recordChange(
                EditorHistoryItem(
                  type: .erase,
                  pageIndex: strokes.first.pageIndex,
                  strokes: strokes,
                  images: images,
                ),
              );
              autosaveAfterDelay();
            });
          },
          setColor: (color) {
            setState(() {
              updateColorBar(color);

              if (currentTool is Highlighter) {
                (currentTool as Highlighter).color = color.withAlpha(
                  Highlighter.alpha,
                );
              } else if (currentTool is Pen) {
                (currentTool as Pen).color = color;
              } else if (currentTool is Select) {
                // Changes color of selected strokes
                final select = currentTool as Select;
                if (select.doneSelecting) {
                  final strokes = select.selectResult.strokes;

                  final colorChange = <Stroke, Change<Color>>{};
                  for (final stroke in strokes) {
                    colorChange[stroke] = Change(
                      previous: stroke.color,
                      current: color,
                    );
                    stroke.color = color;
                  }

                  history.recordChange(
                    EditorHistoryItem(
                      type: .changeColor,
                      pageIndex: strokes.first.pageIndex,
                      strokes: strokes,
                      colorChange: colorChange,
                      images: [],
                    ),
                  );
                  autosaveAfterDelay();
                }
              }
            });
          },
          quillFocus: quillFocus,
          textEditing: currentTool == Tool.textEditing,
          toggleTextEditing: () => setState(() {
            if (currentTool == Tool.textEditing) {
              currentTool = Pen.currentPen;
              for (final page in coreInfo.pages) {
                // unselect text, but maintain cursor position
                page.quill.controller.moveCursorToPosition(
                  page.quill.controller.selection.extentOffset,
                );
                page.quill.focusNode.unfocus();
              }
            } else {
              currentTool = Tool.textEditing;
              quillFocus.value = coreInfo.pages[currentPageIndex].quill
                ..focusNode.requestFocus();
            }
          }),
          undo: undo,
          isUndoPossible: history.canUndo,
          redo: redo,
          isRedoPossible: history.canRedo,
          toggleFingerDrawing: () {
            stows.editorFingerDrawing.value = !stows.editorFingerDrawing.value;
            lastSeenPointerCount = 0;
          },
          pickPhoto: _pickPhotos,
          paste: paste,
          exportAsSba: exportAsSba,
          exportAsPdf: exportAsPdf,
          exportAsPng: exportAsPng,
        ),
      ),
    );

    final Widget body;
    if (isToolbarVertical) {
      body = Row(
        textDirection: stows.editorToolbarAlignment.value == AxisDirection.left
            ? .ltr
            : .rtl,
        children: [
          toolbar,
          Expanded(
            child: Column(
              children: [
                Expanded(child: canvas),
                readonlyBanner,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        verticalDirection:
            stows.editorToolbarAlignment.value == AxisDirection.up
            ? VerticalDirection.up
            : VerticalDirection.down,
        children: [
          Expanded(child: canvas),
          toolbar,
          readonlyBanner,
        ],
      );
    }

    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, savingState, child) {
        // don't allow user to go back until saving is done
        return PopScope(
          canPop: savingState == .saved,
          onPopInvokedWithResult: (didPop, _) {
            switch (savingState) {
              case .waitingToSave:
                assert(!didPop);
                saveToFile(); // trigger save now
                snackBarNeedsToSaveBeforeExiting();
              case .saving:
                assert(!didPop);
                snackBarNeedsToSaveBeforeExiting();
              case .saved:
                break;
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: DynamicMaterialApp.isFullscreen
            ? null
            : AppBar(
                toolbarHeight: kToolbarHeight,
                title: widget.customTitle != null
                    ? Text(widget.customTitle!)
                    : Form(
                        key: _filenameFormKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          controller: filenameTextEditingController,
                          onChanged: renameFile,
                          autofocus: needsNaming,
                          validator: _validateFilenameTextField,
                        ),
                      ),
                leading: SaveIndicator(
                  savingState: savingState,
                  triggerSave: saveToFile,
                ),
                actions: [
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.insert_page_break,
                      cupertinoIcon: CupertinoIcons.add,
                    ),
                    tooltip: t.editor.menu.insertPage,
                    onPressed: () => setState(() {
                      final currentPageIndex = this.currentPageIndex;
                      insertPageAfter(currentPageIndex);
                      CanvasGestureDetector.scrollToPage(
                        pageIndex: currentPageIndex + 1,
                        pages: coreInfo.pages,
                        screenWidth: MediaQuery.sizeOf(context).width,
                        transformationController: _transformationController,
                      );
                    }),
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.grid_view,
                      cupertinoIcon: CupertinoIcons.rectangle_grid_2x2,
                    ),
                    tooltip: t.editor.pages,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AdaptiveAlertDialog(
                          title: Text(t.editor.pages),
                          content: pageManager(context),
                          actions: const [],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Icons.more_vert,
                      cupertinoIcon: CupertinoIcons.ellipsis_vertical,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => bottomSheet(context),
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: colorScheme.surface,
                        constraints: const BoxConstraints(maxWidth: 500),
                      );
                    },
                  ),
                ],
              ),
        body: ValueListenableBuilder(
          valueListenable: stows.peripheralDebugDataWindow,
          child: body,
          builder: (context, enabled, child) {
            if (!enabled) return child!;
            return Stack(
              fit: StackFit.expand,
              children: [
                child!,
                _PeripheralDebugOverlay(dataListenable: _peripheralDebugData),
              ],
            );
          },
        ),
        floatingActionButton:
            (DynamicMaterialApp.isFullscreen &&
                !stows.editorToolbarShowInFullscreen.value)
            ? FloatingActionButton(
                shape: platform.isCupertino ? const CircleBorder() : null,
                onPressed: () {
                  DynamicMaterialApp.setFullscreen(false, updateSystem: true);
                },
                child: const Icon(Icons.fullscreen_exit),
              )
            : null,
      ),
    );
  }

  void snackBarNeedsToSaveBeforeExiting() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.editor.needsToSaveBeforeExiting)));
  }

  Widget bottomSheet(BuildContext context) {
    final Brightness brightness = Theme.brightnessOf(context);
    final invert = stows.editorAutoInvert.value && brightness == .dark;
    final int currentPageIndex = this.currentPageIndex;

    return EditorBottomSheet(
      invert: invert,
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      setBackgroundPattern: (pattern) => setState(() {
        if (coreInfo.readOnly) return;
        final previous = coreInfo.backgroundPattern;
        coreInfo.backgroundPattern = pattern;
        stows.lastBackgroundPattern.value = pattern;
        history.recordChange(
          EditorHistoryItem(
            type: .backgroundPattern,
            pageIndex: currentPageIndex,
            backgroundPatternChange: Change(
              previous: previous,
              current: pattern,
            ),
            strokes: [],
            images: [],
          ),
        );
        autosaveAfterDelay();
      }),
      setLineHeight: (lineHeight) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineHeight = lineHeight;
        stows.lastLineHeight.value = lineHeight;
        autosaveAfterDelay();
      }),
      setLineThickness: (lineThickness) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineThickness = lineThickness;
        stows.lastLineThickness.value = lineThickness;
        autosaveAfterDelay();
      }),
      removeBackgroundImage: () => setState(() {
        if (coreInfo.readOnly) return;

        final page = coreInfo.pages[currentPageIndex];
        if (page.backgroundImage == null) return;
        page.images.add(page.backgroundImage!);
        page.backgroundImage = null;

        autosaveAfterDelay();
      }),
      redrawImage: () => setState(() {}),
      clearPage: () {
        clearPage(currentPageIndex);
      },
      clearAllPages: clearAllPages,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      pickPhotos: _pickPhotos,
      importPdf: importPdf,
      canRasterPdf: Editor.canRasterPdf,
      getIsWatchingServer: () => _watchServerTimer?.isActive ?? false,
      setIsWatchingServer: (bool watch) {
        if (watch) {
          _watchServerTimer ??= Timer.periodic(
            const Duration(seconds: 5),
            (_) => _refreshCurrentNote(),
          );
          if (coreInfo.readOnlyReason != .watchingServer) {
            assert(coreInfo.readOnlyReason == null);
            coreInfo.readOnlyReason = .watchingServer;
            if (mounted) setState(() {});
          }
        } else {
          _watchServerTimer?.cancel();
          _watchServerTimer = null;
          if (coreInfo.readOnlyReason == .watchingServer) {
            coreInfo.readOnlyReason = null;
            if (mounted) setState(() {});
          }
        }
      },
    );
  }

  Widget pageBuilder(BuildContext context, int pageIndex) {
    final page = coreInfo.pages[pageIndex];
    final currentStroke = Pen.currentStroke?.pageIndex == pageIndex
        ? Pen.currentStroke
        : null;
    return Canvas(
      path: coreInfo.filePath,
      page: page,
      pageIndex: pageIndex,
      textEditing: currentTool == Tool.textEditing,
      coreInfo: coreInfo,
      currentStroke: currentStroke,
      currentStrokeDetectedShape:
          currentTool is ShapePen && currentStroke != null
          ? ShapePen.detectedShape
          : null,
      currentSelection: () {
        if (currentTool is! Select) return null;
        final selectResult = (currentTool as Select).selectResult;
        if (selectResult.pageIndex != pageIndex) return null;
        return selectResult;
      }(),
      setAsBackground: (EditorImage image) {
        if (page.backgroundImage != null) {
          // restore previous background image as normal image
          page.images.add(page.backgroundImage!);
        }
        page.images.remove(image);
        page.backgroundImage = image;

        CanvasImage.activeListener
            .notifyListenersPlease(); // un-select active image

        autosaveAfterDelay();
        setState(() {});
      },
      currentTool: currentTool,
      currentScale: _transformationController.value.approxScale,
      stylusHoverPreview: _stylusHoverPreview?.pageIndex == pageIndex
          ? _stylusHoverPreview
          : null,
    );
  }

  Widget pageManager(BuildContext context) {
    return EditorPageManager(
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      insertPageAfter: insertPageAfter,
      duplicatePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages[pageIndex];
        final newPage = page.copyWith(
          strokes: page.strokes
              .map((stroke) => stroke.copy()..pageIndex += 1)
              .toList(),
          images: page.images
              .map((image) => image.copy()..pageIndex += 1)
              .toList(),
          quill: QuillStruct(
            controller: flutter_quill.QuillController(
              document: flutter_quill.Document.fromDelta(
                page.quill.controller.document.toDelta(),
              ),
              selection: const TextSelection.collapsed(offset: 0),
            ),
            focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
          ),
          backgroundImage: page.backgroundImage?.copy()?..pageIndex += 1,
        );
        coreInfo.pages.insert(pageIndex + 1, newPage);
        listenToQuillChanges(newPage.quill, pageIndex + 1);
        history.recordChange(
          EditorHistoryItem(
            type: .insertPage,
            pageIndex: pageIndex,
            strokes: const [],
            images: const [],
            page: newPage,
          ),
        );
        autosaveAfterDelay();
      }),
      clearPage: clearPage,
      deletePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages.removeAt(pageIndex);
        createPage(pageIndex - 1);
        history.recordChange(
          EditorHistoryItem(
            type: .deletePage,
            pageIndex: pageIndex,
            strokes: const [],
            images: const [],
            page: page,
          ),
        );
        autosaveAfterDelay();
      }),
      transformationController: _transformationController,
    );
  }

  void insertPageAfter(int pageIndex) => setState(() {
    if (coreInfo.readOnly) return;
    final page = EditorPage();
    coreInfo.pages.insert(pageIndex + 1, page);
    listenToQuillChanges(page.quill, pageIndex + 1);
    history.recordChange(
      EditorHistoryItem(
        type: .insertPage,
        pageIndex: pageIndex + 1,
        strokes: const [],
        images: const [],
        page: page,
      ),
    );
    autosaveAfterDelay();
  });

  void clearPage(int pageIndex) {
    if (coreInfo.readOnly) return;
    final page = coreInfo.pages[pageIndex];
    setState(() {
      final removedStrokes = page.strokes.toList();
      final removedImages = page.images.toList();
      page.strokes.clear();
      page.images.clear();
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: pageIndex,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
      autosaveAfterDelay();
    });
  }

  void clearAllPages() {
    if (coreInfo.readOnly) return;
    setState(() {
      final removedStrokes = <Stroke>[];
      final removedImages = <EditorImage>[];
      for (final page in coreInfo.pages) {
        removedStrokes.addAll(page.strokes);
        removedImages.addAll(page.images);
        page.strokes.clear();
        page.images.clear();
      }
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: 0,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
    });
    autosaveAfterDelay();
  }

  Future<void> showVersionTooNewDialog() async {
    final disableReadOnly =
        await showDialog(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
            title: Text(t.editor.versionTooNew.title),
            content: Text(t.editor.versionTooNew.subtitle),
            actions: [
              CupertinoDialogAction(
                child: Text(t.common.cancel),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                child: Text(t.editor.versionTooNew.allowEditing),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!disableReadOnly) return;

    if (coreInfo.readOnlyReason == .versionTooNew) {
      coreInfo.readOnlyReason = null;
      if (mounted) setState(() {});
    }
  }

  late int _lastCurrentPageIndex = coreInfo.initialPageIndex ?? 0;

  /// The index of the page that is currently centered on screen.
  int get currentPageIndex {
    if (!mounted) return _lastCurrentPageIndex;

    final screenWidth = MediaQuery.sizeOf(context).width;

    return _lastCurrentPageIndex = getPageIndexFromScrollPosition(
      scrollY: -scrollY,
      screenWidth: screenWidth,
      pages: coreInfo.pages,
    );
  }

  @visibleForTesting
  static int getPageIndexFromScrollPosition({
    required double scrollY,
    required double screenWidth,
    required List<EditorPage> pages,
  }) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final bottomOfPage = CanvasGestureDetector.getTopOfPage(
        pageIndex: pageIndex + 1, // top of next page
        pages: pages,
        screenWidth: screenWidth,
      );

      if (scrollY < bottomOfPage) {
        return pageIndex;
      }
    }
    // below the last page
    return pages.length - 1;
  }

  @override
  void dispose() {
    unawaited(_cleanUpAsync());

    DynamicMaterialApp.removeFullscreenListener(_setState);
    Pen.advancedSettingsOpen.removeListener(_onPenAdvancedSettingsOpenChanged);

    _delayedSaveTimer?.cancel();
    _watchServerTimer?.cancel();
    _lastSeenPointerCountTimer?.cancel();
    _applePencilSubscriptionTimer?.cancel();
    _applePencilInteractionSubscription?.cancel();
    _applePencilHoverSubscription?.cancel();
    _applePencilTelemetrySubscription?.cancel();
    _peripheralDebugData.dispose();

    _removeKeybindings();

    // manually save pen properties since the listeners don't fire if a property is changed
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
    stows.lastShapePenOptions.notifyListeners();

    super.dispose();
  }

  Future<void> _cleanUpAsync() async {
    try {
      if (_renameTimer?.isActive ?? false) {
        _renameTimer!.cancel();
        await _renameFileNow();
        filenameTextEditingController.dispose();
      }
      await saveToFile();
    } finally {
      coreInfo.dispose();
    }
  }
}
