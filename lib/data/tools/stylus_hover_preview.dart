/// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).
library;

import 'dart:ui';

/// The shape of the stylus hover preview.
enum StylusHoverPreviewKind {
  /// A filled footprint for drawing tools.
  drawing,

  /// An outlined footprint for the eraser.
  eraser,
}

/// A page-local preview of where a hovering stylus will affect the canvas.
class StylusHoverPreview {
  /// Creates a stylus hover preview.
  const StylusHoverPreview({
    required this.pageIndex,
    required this.position,
    required this.radius,
    required this.color,
    required this.opacity,
    required this.kind,
    required this.invertedStylus,
    this.directionAngle,
  });

  /// The page that contains [position].
  final int pageIndex;

  /// The hover position in page coordinates.
  final Offset position;

  /// The preview radius in page coordinates.
  final double radius;

  /// The tool color to preview.
  final Color color;

  /// The opacity after applying stylus hover distance.
  final double opacity;

  /// The preview shape to draw.
  final StylusHoverPreviewKind kind;

  /// Whether the preview came from an inverted stylus.
  final bool invertedStylus;

  /// The current nib or pencil-roll direction in radians.
  final double? directionAngle;

  /// Calculates the preview opacity from a Flutter pointer hover distance.
  static double opacityFromDistance({
    required double distance,
    required double distanceMax,
  }) {
    if (distanceMax <= 0) return 0.45;

    final closeness = (1 - distance / distanceMax).clamp(0.0, 1.0);
    return 0.15 + (0.65 - 0.15) * closeness;
  }

  @override
  bool operator ==(Object other) {
    return other is StylusHoverPreview &&
        other.pageIndex == pageIndex &&
        other.position == position &&
        other.radius == radius &&
        other.color == color &&
        other.opacity == opacity &&
        other.kind == kind &&
        other.invertedStylus == invertedStylus &&
        other.directionAngle == directionAngle;
  }

  @override
  int get hashCode => Object.hash(
    pageIndex,
    position,
    radius,
    color,
    opacity,
    kind,
    invertedStylus,
    directionAngle,
  );
}
