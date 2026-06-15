/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/i18n/strings.g.dart';

class Highlighter extends Pen {
  Highlighter()
    : super(
        name: t.editor.pens.highlighter,
        sizeMin: 10,
        sizeMax: 100,
        sizeStep: 10,
        icon: highlighterIcon,
        options: stows.lastHighlighterOptions.value,
        pressureEnabled: false,
        pressureCurve: PressureCurve.neutral(),
        tiltSensitivity: 0,
        rollSensitivity: 0,
        color: Colors.yellow.withAlpha(Highlighter.alpha),
        toolId: .highlighter,
      );

  static const alpha = 100;

  static Pen currentHighlighter = Highlighter();

  static const highlighterIcon = FontAwesomeIcons.highlighter;
}
