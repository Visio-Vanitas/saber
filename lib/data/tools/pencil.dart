/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';

class Pencil extends Pen {
  Pencil()
    : super(
        name: t.editor.pens.pencil,
        sizeMin: 1,
        sizeMax: 15,
        sizeStep: 1,
        icon: pencilIcon,
        options: stows.lastPencilOptions.value,
        pressureEnabled: true,
        pressureCurve: stows.pencilPressureCurve,
        tiltSensitivity: stows.lastPencilTiltSensitivity.value,
        rollSensitivity: stows.lastPencilRollSensitivity.value,
        color: Color(stows.lastPencilColor.value),
        toolId: .pencil,
      );

  static var currentPencil = Pencil();

  static const pencilIcon = FontAwesomeIcons.pencil;
}
