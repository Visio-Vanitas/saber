<!-- 🤖 Generated wholly or partially with OpenAI Codex (GPT-5). -->

# Apple Pencil Stroke Optimization Research

## Goal

Improve Saber writing quality from Apple Pencil telemetry, with Apple Pencil Pro
as the first-class target. Prefer native Swift telemetry over Flutter pointer
events whenever it gives richer or more reliable data.

## Current Saber Pipeline

- Flutter receives pointer events in `CanvasGestureDetector`.
- `StylusSample` currently stores `PointerDeviceKind`, normalized pressure,
  tilt, and orientation.
- `Pen.onDragUpdate` passes only an effective pressure into `Stroke.addPoint`.
- `Stroke` stores `PointVector(x, y, pressure)` in the `p` field and uses
  `perfect_freehand` to generate the stroke polygon.
- Pencil tilt currently only nudges effective pressure for the pencil tool.
- The existing Swift bridge already emits Apple Pencil hardware interactions
  and hover pose data.

The current `.sbn2` format version is 19. Version 13 moved stroke points to
compact BSON binary values containing x, y, and optional pressure. For Apple
Pencil Pro v1, we should consider a format bump so roll, altitude, azimuth, and
timing can be replayed instead of only being baked into x/y/pressure.

## V1 Product Decisions

- v1 may extend the `.sbn2` format so Apple Pencil pose data can survive saving,
  reopening, export re-rendering, and cross-device sync.
- Apple Pencil Pro roll should influence both pencil texture direction and
  calligraphy nib angle, depending on the active tool.
- Swift native telemetry is the preferred source for writing samples. Flutter
  pointer events remain the fallback path.

## Native Apple APIs

Primary public API references:

- Apple UIKit `UITouch`: <https://developer.apple.com/documentation/uikit/uitouch>
- Apple UIKit `UIEvent`: <https://developer.apple.com/documentation/uikit/uievent>
- Apple UIKit `UIHoverGestureRecognizer`: <https://developer.apple.com/documentation/uikit/uihovergesturerecognizer>
- Apple UIKit `UIPencilInteraction`: <https://developer.apple.com/documentation/uikit/uipencilinteraction>
- Flutter `PointerEvent`: <https://api.flutter.dev/flutter/gestures/PointerEvent-class.html>

Verified against local Xcode 26.4 SDK headers:

- `UITouch.type == .pencil` identifies Apple Pencil touches.
- `UITouch.preciseLocation(in:)` and `precisePreviousLocation(in:)` provide
  higher precision than normal hit-test locations.
- `UITouch.force` and `maximumPossibleForce` expose native pressure.
- `UITouch.altitudeAngle` and `azimuthAngle(in:)` expose pencil pose.
- `UITouch.rollAngle` is available on iOS 17.5+ and returns `0` on pencils that
  do not support roll. The SDK notes that Pencil Pro roll is relative to the
  angle when the pencil becomes active or wakes up.
- `UIEvent.coalescedTouches(for:)` exposes delivered-but-not-forwarded touch
  samples; this is useful for denser, less jagged strokes.
- `UIEvent.predictedTouches(for:)` exposes estimated future samples; these
  should improve current-stroke responsiveness but must not be committed as
  real stroke points.
- `UIHoverGestureRecognizer.zOffset` is available on iOS 16.1+.
- `UIHoverGestureRecognizer.azimuthAngle(in:)` and `altitudeAngle` are
  available on iOS 16.4+.
- `UIHoverGestureRecognizer.rollAngle` is available on iOS 17.5+.
- `UIPencilInteraction.preferredSqueezeAction`, squeeze events, tap hover pose,
  squeeze hover pose, and `UIPencilHoverPose.rollAngle` are available on iOS
  17.5+.

## Capability-Based Model Adaptation

Do not hard-code a Pencil model name. Public APIs do not expose a stable
"Apple Pencil Pro" model identifier. Adapt from observed capabilities:

- Pro profile: `rollAngle` support and/or squeeze events.
- Hover profile: hover `zOffset` plus altitude or azimuth.
- Double-tap profile: `UIPencilInteraction` tap event.
- Basic pressure profile: `UITouch.force` with useful `maximumPossibleForce`.
- Basic stylus profile: pencil type and precise locations without pressure.

This is safer across iPadOS updates and covers Apple Pencil USB-C or future
models without special casing.

## Proposed Swift Bridge

Add a native telemetry EventChannel, separate from hardware gestures:

`saber/apple_pencil_telemetry/events`

Implementation shape:

- Attach a passive `UIGestureRecognizer` to the Flutter view.
- Set `cancelsTouchesInView = false`, no delays, no exclusive touch type.
- Allow simultaneous recognition so Flutter keeps receiving normal touch input.
- In `touchesBegan/Moved/Ended/Cancelled`, filter `touch.type == .pencil`.
- For each touch, emit:
  - `phase`
  - UIKit view coordinates and precise coordinates
  - timestamp
  - normalized pressure from `force / maximumPossibleForce`
  - raw force and max force for calibration
  - altitude angle
  - azimuth angle and azimuth unit vector
  - roll angle when available
  - major radius and tolerance
  - estimated properties and expected future updates
  - coalesced samples
  - predicted samples
- Keep the existing hover bridge, but share a common Dart telemetry model so
  hover, touch, and squeeze hover-pose samples use the same field names.

Coordinate note: UIKit view points should usually match Flutter logical pixels
for the Flutter view, but this must be verified on device after zoom/rotation
and multitasking/split view.

## Stroke Algorithm References

### perfect_freehand

Sources:

- Dart package: <https://pub.dev/packages/perfect_freehand>
- Upstream TypeScript implementation: <https://github.com/steveruizok/perfect-freehand>

Useful behavior:

- Converts input points into adjusted stroke points, then into an outline
  polygon.
- Accepts per-point pressure and has `size`, `thinning`, `smoothing`,
  `streamline`, taper, and simulated pressure options.
- Saber already uses it, so this is the lowest-risk path.

Best fit for Saber v1:

- Feed denser coalesced native samples into the existing stroke.
- Use native pressure instead of simulated pressure whenever possible.
- Apply a pressure response curve before adding points.
- Convert tilt/roll into effective pressure or size-like behavior only when it
  can be persisted through existing pressure values.

### libmypaint

Source: <https://github.com/mypaint/libmypaint>

Useful behavior:

- Procedural brush engine used by MyPaint and other apps.
- Models many input channels: pressure, fine/gross speed, stroke progress,
  tilt ascension/declination, direction, attack angle, view zoom, and barrel
  rotation.
- Uses mapping curves from inputs to brush settings.

Best fit for Saber:

- Borrow the idea of input mappings and filtered speed channels.
- Do not import the engine in v1; it is raster/dab-oriented and would fight
  Saber's current vector stroke storage.

### Krita

Source: <https://github.com/KDE/krita>

Useful behavior:

- Mature open-source drawing app with brush engines, stabilizers, pressure and
  tilt mappings.

Best fit for Saber:

- Treat as a reference for UX concepts such as pressure curves, stabilizer
  strength, and sensor-to-brush mappings.
- Avoid porting internals directly; they are coupled to Krita's raster engine.

## V1 Format Extension

Use a new `.sbn2` format version, tentatively v20.

Keep the existing `p` field as the canonical baseline path:

- Existing stroke rendering, SVG/PDF export, and old-note compatibility can keep
  using `p`.
- Older Saber versions will mark v20 notes as too new instead of silently
  dropping pose data.
- If a future downgrade/export path is needed, it can strip the pose field and
  keep `p` as a readable pressure-only stroke.

Add a stroke-level pose field, `ap` for Apple Pencil pose:

- Store it only when there is meaningful native Apple Pencil telemetry.
- Align entries by point index with `p` whenever possible.
- If predicted samples are used for live rendering, do not persist them as final
  `ap` entries.
- Prefer compact BSON binary arrays for size and consistency with `p`.

Suggested per-sample payload:

- timestamp delta from stroke start, in seconds or milliseconds
- pressure after native normalization, for debugging/calibration
- altitude angle
- azimuth angle, or azimuth x/y unit vector
- roll angle
- native source flags, such as real/coalesced/estimated

The first implementation can keep `PointVector` unchanged and attach pose
samples beside the point list. That avoids modifying `perfect_freehand` types
and keeps the storage upgrade localized to `Stroke` serialization, parser
tests, and the new telemetry model.

## V1 Writing Improvements

With the v20 pose extension:

- Use Swift coalesced touches for actual committed points.
- Use Swift predicted touches only for live current-stroke rendering; remove or
  replace them when real samples arrive.
- Normalize pressure using native force/max force, then apply a configurable
  response curve.
- Add a light one-euro/EMA-style pressure filter to reduce pressure jitter
  without lagging sharp changes too much.
- Add position dedupe based on tool size and speed, but preserve dense samples
  on curves.
- Pencil tool:
  - map low altitude / high tilt to wider or darker effective pressure;
  - use Apple Pencil Pro roll to rotate or bias pencil grain/texture direction;
  - persist roll so reopened notes can re-render the same grain direction.
- Fountain pen:
  - make pressure response smoother and less jumpy;
  - use Apple Pencil Pro roll as the calligraphy nib angle;
  - use altitude and azimuth as secondary inputs for nib projection and width.
- Highlighter:
  - mostly ignore pressure/tilt for width stability;
  - use coalesced samples for smoother edges.

## Later Format-Aware Improvements

After v20, richer rendering can build on the persisted pose data:

- store calibrated pressure curve settings per device/profile;
- add richer calligraphy stroke outlines that are not limited to
  `perfect_freehand` pressure widening;
- persist tool-specific render metadata if pencil grain or calligraphy geometry
  needs more than the raw pose samples.

Do not persist predicted samples as final data unless they have been replaced by
real or coalesced touches.

## Open Questions

- Do we want a visible pressure/tilt calibration setting, or hidden defaults
  tuned for Pencil Pro first?
- Should predicted touches be enabled by default if they make the live stroke
  feel faster but occasionally need visible correction?
- Should v20 store azimuth as an angle, a unit vector, or both? Angle is smaller;
  unit vector avoids repeated trig and is already available from UIKit.

## Recommended Implementation Order

1. Add native Swift Apple Pencil telemetry recognizer and Dart parser tests.
2. Add a v20 stroke pose schema and backward-compatible read/write tests.
3. Feed coalesced real samples into `StylusSample` / `Pen.onDragUpdate`.
4. Add pressure response curve and filter tests.
5. Use predicted samples only for current-stroke preview.
6. Add Pencil Pro roll-aware pencil and calligraphy behavior behind a setting.
7. Test on the connected iPad with Apple Pencil Pro using pressure, tilt, roll,
   hover, squeeze, and quick strokes at several zoom levels.
