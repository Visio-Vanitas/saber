/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/apple_pencil/apple_pencil_interaction.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/tool_id.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Apple Pencil hardware actions', () {
    late _FakeApplePencilInteractionService applePencilService;

    setUp(() {
      FlavorConfig.setup();
      FileManager.documentsDirectory =
          '$tmpDir/apple_pencil_editor_test/'
          '${FileManager.appRootDirectoryPrefix}';
      stows.lastTool.value = ToolId.fountainPen;
      stows.applePencilDoubleTapAction.value = ApplePencilAction.system;
      stows.applePencilSqueezeAction.value = ApplePencilAction.system;
      stows.disableEraserAfterUse.value = false;
      applePencilService = _FakeApplePencilInteractionService();
    });

    tearDown(() async {
      await applePencilService.dispose();
    });

    testWidgets('double-tap follows system eraser preference', (tester) async {
      final editorState = await tester._pumpEditor(applePencilService);

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.toggleEraser,
        ),
      );
      await tester.pump();

      expect(editorState.currentTool, isA<Eraser>());
    });

    testWidgets('double-tap toggles the color palette closed', (tester) async {
      await tester._pumpEditor(applePencilService);
      final toolbarState = tester.state<ToolbarState>(find.byType(Toolbar));

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.showColorPalette,
        ),
      );
      await tester.pump();

      expect(toolbarState.isColorOptionsOpen, isTrue);

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.showColorPalette,
        ),
      );
      await tester.pump();

      expect(toolbarState.isColorOptionsOpen, isFalse);
    });

    testWidgets('double-tap toggles ink attributes closed', (tester) async {
      await tester._pumpEditor(applePencilService);
      final toolbarState = tester.state<ToolbarState>(find.byType(Toolbar));

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.showInkAttributes,
        ),
      );
      await tester.pump();

      expect(toolbarState.currentToolOptions, ToolOptions.pen);

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.showInkAttributes,
        ),
      );
      await tester.pump();

      expect(toolbarState.currentToolOptions, ToolOptions.hide);
    });

    testWidgets('Saber override wins over system preference', (tester) async {
      stows.applePencilDoubleTapAction.value = ApplePencilAction.disabled;
      final editorState = await tester._pumpEditor(applePencilService);

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: ApplePencilAction.toggleEraser,
        ),
      );
      await tester.pump();

      expect(editorState.currentTool, isNot(isA<Eraser>()));
    });

    testWidgets(
      'squeeze temporarily uses eraser when auto-disable is enabled',
      (tester) async {
        stows.disableEraserAfterUse.value = true;
        final editorState = await tester._pumpEditor(applePencilService);
        final initialTool = editorState.currentTool;

        applePencilService.add(
          const ApplePencilInteractionEvent(
            gesture: ApplePencilHardwareGesture.squeeze,
            phase: ApplePencilInteractionPhase.began,
            preferredAction: ApplePencilAction.toggleEraser,
          ),
        );
        await tester.pump();

        expect(editorState.currentTool, isA<Eraser>());

        applePencilService.add(
          const ApplePencilInteractionEvent(
            gesture: ApplePencilHardwareGesture.squeeze,
            phase: ApplePencilInteractionPhase.changed,
            preferredAction: ApplePencilAction.toggleEraser,
          ),
        );
        await tester.pump();

        expect(editorState.currentTool, isA<Eraser>());

        applePencilService.add(
          const ApplePencilInteractionEvent(
            gesture: ApplePencilHardwareGesture.squeeze,
            phase: ApplePencilInteractionPhase.ended,
            preferredAction: ApplePencilAction.toggleEraser,
          ),
        );
        await tester.pump();

        expect(editorState.currentTool, initialTool);
      },
    );

    testWidgets('squeeze keeps eraser selected when auto-disable is disabled', (
      tester,
    ) async {
      final editorState = await tester._pumpEditor(applePencilService);

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.squeeze,
          phase: ApplePencilInteractionPhase.began,
          preferredAction: ApplePencilAction.toggleEraser,
        ),
      );
      await tester.pump();

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.squeeze,
          phase: ApplePencilInteractionPhase.ended,
          preferredAction: ApplePencilAction.toggleEraser,
        ),
      );
      await tester.pump();

      expect(editorState.currentTool, isA<Eraser>());
    });

    testWidgets('squeeze opens the color palette', (tester) async {
      await tester._pumpEditor(applePencilService);
      final toolbarState = tester.state<ToolbarState>(find.byType(Toolbar));

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.squeeze,
          phase: ApplePencilInteractionPhase.began,
          preferredAction: ApplePencilAction.showColorPalette,
        ),
      );
      await tester.pump();

      expect(toolbarState.isColorOptionsOpen, isTrue);
    });

    testWidgets('squeeze opens the current tool options', (tester) async {
      await tester._pumpEditor(applePencilService);
      final toolbarState = tester.state<ToolbarState>(find.byType(Toolbar));

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.squeeze,
          phase: ApplePencilInteractionPhase.began,
          preferredAction: ApplePencilAction.showInkAttributes,
        ),
      );
      await tester.pump();

      expect(toolbarState.currentToolOptions, ToolOptions.pen);
    });

    testWidgets('squeeze opens the contextual tool palette', (tester) async {
      await tester._pumpEditor(applePencilService);
      final toolbarState = tester.state<ToolbarState>(find.byType(Toolbar));

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.squeeze,
          phase: ApplePencilInteractionPhase.began,
          preferredAction: ApplePencilAction.showToolPalette,
        ),
      );
      await tester.pump();

      expect(toolbarState.currentToolOptions, ToolOptions.pen);
    });

    testWidgets('unknown system action is a no-op', (tester) async {
      final editorState = await tester._pumpEditor(applePencilService);
      final initialTool = editorState.currentTool;

      applePencilService.add(
        const ApplePencilInteractionEvent(
          gesture: ApplePencilHardwareGesture.doubleTap,
          preferredAction: null,
        ),
      );
      await tester.pump();

      expect(editorState.currentTool, initialTool);
    });
  });
}

class _FakeApplePencilInteractionService
    implements ApplePencilInteractionService {
  final _controller = StreamController<ApplePencilInteractionEvent>.broadcast();

  @override
  Stream<ApplePencilInteractionEvent> get events => _controller.stream;

  void add(ApplePencilInteractionEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

extension on WidgetTester {
  Future<EditorState> _pumpEditor(
    ApplePencilInteractionService applePencilService,
  ) async {
    await pumpWidget(
      MaterialApp(
        home: Editor(
          path: '/apple-pencil-test',
          applePencilInteractionService: applePencilService,
        ),
      ),
    );
    await pump();
    return state<EditorState>(find.byType(Editor));
  }
}
