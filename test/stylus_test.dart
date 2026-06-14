/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/apple_pencil/apple_pencil_interaction.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/stylus_hover_preview.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Stylus', () {
    setUp(() {
      FlavorConfig.setup();
      FileManager.documentsDirectory =
          '$tmpDir/stylus_test/'
          '${FileManager.appRootDirectoryPrefix}';
      stows.editorFingerDrawing.value = false;
      stows.applePencilTipPreview.value = true;
      stows.lastTool.value = Pen.fountainPen().toolId;
    });

    // If you quickly draw, sometimes there's no hover event before the pointer down event
    for (final withHover in [true, false]) {
      testWidgets('Normal input should draw a stroke', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        expect(page.strokes, isEmpty);
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
      });

      // Styluses like the S Pen use a button to trigger the eraser.
      testWidgets('Pressing the stylus button should erase', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
        await tester._stylusDrag(
          editorState,
          withHover,
          buttons: kSecondaryButton,
        );
        expect(page.strokes, hasLength(0));
      });

      // Styluses like the Noris Digital Jumbo have an eraser on the bottom.
      testWidgets('Inverse stylus should erase', (tester) async {
        final editorState = await tester._pumpEditor();
        await tester.pump();
        final page = editorState.coreInfo.pages.first;
        await tester._stylusDrag(editorState, withHover);
        expect(page.strokes, hasLength(1));
        await tester._stylusDrag(editorState, withHover, kind: .invertedStylus);
        expect(page.strokes, hasLength(0));
      });
    }

    testWidgets('Stylus hover should show a drawing preview', (tester) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();

      final preview = editorState.stylusHoverPreview;
      expect(preview, isNotNull);
      expect(preview!.kind, StylusHoverPreviewKind.drawing);
      expect(preview.pageIndex, 0);
      expect(preview.color, (editorState.currentTool as Pen).color);
      expect(preview.radius, (editorState.currentTool as Pen).options.size / 2);
      expect(editorState.coreInfo.pages.first.strokes, isEmpty);
      expect(editorState.history.canUndo, isFalse);
    });

    testWidgets('Mouse hover should not show a stylus preview', (tester) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .mouse);
      await gesture.moveTo(center);
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Native Apple Pencil hover should show a drawing preview', (
      tester,
    ) async {
      final hoverService = _FakeApplePencilHoverService();
      addTearDown(hoverService.dispose);

      final editorState = await tester._pumpEditor(
        applePencilHoverService: hoverService,
      );
      await tester.pump();
      final center = tester.getCenter(find.byType(Editor));

      hoverService.add(
        ApplePencilHoverEvent(
          position: center,
          phase: ApplePencilInteractionPhase.changed,
          zOffset: 0.2,
        ),
      );
      await tester.pump();

      final preview = editorState.stylusHoverPreview;
      expect(preview, isNotNull);
      expect(preview!.kind, StylusHoverPreviewKind.drawing);

      tester.binding.handlePointerEvent(
        PointerHoverEvent(kind: PointerDeviceKind.mouse, position: center),
      );
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNotNull);

      hoverService.add(
        ApplePencilHoverEvent(
          position: center,
          phase: ApplePencilInteractionPhase.ended,
        ),
      );
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Pointer down should hide the stylus preview', (tester) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();
      expect(editorState.stylusHoverPreview, isNotNull);

      await gesture.down(center);
      await tester.pump();
      expect(editorState.stylusHoverPreview, isNull);
      await gesture.up();
    });

    testWidgets('Stylus hover should remain briefly before timeout', (
      tester,
    ) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();
      expect(editorState.stylusHoverPreview, isNotNull);

      await tester.pump(const Duration(milliseconds: 300));
      expect(editorState.stylusHoverPreview, isNotNull);

      await tester.pump(const Duration(milliseconds: 700));

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Stylus hover should clear outside a page', (tester) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();
      expect(editorState.stylusHoverPreview, isNotNull);

      final outsidePage = editorState.coreInfo.pages.first.renderBox!
          .localToGlobal(const Offset(-20, -20));

      editorState.onStylusHover(
        PointerHoverEvent(
          kind: PointerDeviceKind.stylus,
          position: outsidePage,
        ),
      );
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Synthesized stylus hover should clear preview after timeout', (
      tester,
    ) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();
      expect(editorState.stylusHoverPreview, isNotNull);

      tester.binding.handlePointerEvent(
        PointerHoverEvent(
          pointer: 1,
          kind: PointerDeviceKind.stylus,
          position: center,
          synthesized: true,
        ),
      );
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNotNull);

      await tester.pump(const Duration(seconds: 1));

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Disabled Apple Pencil preview setting should hide preview', (
      tester,
    ) async {
      stows.applePencilTipPreview.value = false;
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .stylus);
      await gesture.moveTo(center);
      await tester.pump();

      expect(editorState.stylusHoverPreview, isNull);
    });

    testWidgets('Inverted stylus hover should show eraser preview', (
      tester,
    ) async {
      final editorState = await tester._pumpEditor();
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final gesture = await tester.createGesture(kind: .invertedStylus);
      await gesture.moveTo(center);
      await tester.pump();

      final preview = editorState.stylusHoverPreview;
      expect(preview, isNotNull);
      expect(preview!.kind, StylusHoverPreviewKind.eraser);
      expect(preview.radius, Eraser().size);
      expect(preview.invertedStylus, isTrue);
    });
  });
}

class _FakeApplePencilHoverService implements ApplePencilHoverService {
  final _controller = StreamController<ApplePencilHoverEvent>.broadcast();

  @override
  Stream<ApplePencilHoverEvent> get events => _controller.stream;

  void add(ApplePencilHoverEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

extension on WidgetTester {
  Future<EditorState> _pumpEditor({
    ApplePencilHoverService? applePencilHoverService,
  }) async {
    await pumpWidget(
      MaterialApp(
        home: Editor(
          path: '/stylus-test',
          applePencilHoverService: applePencilHoverService,
        ),
      ),
    );
    final editorState = state<EditorState>(find.byType(Editor));
    addTearDown(editorState.cancelAutosaveAndMarkSaved);
    return editorState;
  }

  /// Similar to [timedDragFrom] but with support for [PointerDeviceKind].
  // TODO(adil192): Submit PRs to Flutter:
  //                - Add [PointerDeviceKind] to [timedDragFrom]
  //                - Add [buttons] to [TestPointer.hover]
  Future<void> _stylusDrag(
    EditorState editorState,
    bool withHover, {
    PointerDeviceKind kind = .stylus,
    int buttons = kPrimaryButton,
  }) async {
    final center = getCenter(find.byType(Editor));
    final gesture = await createGesture(kind: kind, buttons: buttons);

    if (withHover) {
      await gesture.moveTo(center);
      if (buttons == kSecondaryButton) {
        // Right now, [TestPointer.hover] doesn't pass through [buttons],
        // so fake it until that gets fixed in Flutter.
        editorState.onStylusButtonChanged(true);
      }
    }

    await gesture.down(center);
    for (var i = 0; i < 10; ++i) {
      await gesture.moveBy(
        Offset(i / 2, i / 2),
        timeStamp: Duration(seconds: i),
      );
    }
    await gesture.up(timeStamp: const Duration(seconds: 10));
  }
}
