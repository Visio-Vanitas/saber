// 🤖 Generated wholly or partially with OpenAI Codex (GPT-5).

import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let maxApplePencilInteractionSetupAttempts = 20

  private var applePencilInteractionChannel: FlutterEventChannel?
  private var applePencilInteractionHandler: AnyObject?
  private var applePencilHoverChannel: FlutterEventChannel?
  private var applePencilHoverHandler: AnyObject?
  private var applePencilTelemetryChannel: FlutterEventChannel?
  private var applePencilTelemetryHandler: AnyObject?
  private var applePencilInteractionSetupAttempts = 0

  /// Registers all pubspec-referenced Flutter plugins in the given registry
  static func registerPlugins(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      // The following code will be called upon WorkmanagerPlugin's registration.
      AppDelegate.registerPlugins(with: registry)
    }

    // At least 12 hours between background fetches
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(12 * 60 * 60))

    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    setupApplePencilInteraction()
    return didFinishLaunching
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    AppDelegate.registerPlugins(with: engineBridge.pluginRegistry)
  }

  private func setupApplePencilInteraction() {
    guard applePencilInteractionHandler == nil || applePencilHoverHandler == nil || applePencilTelemetryHandler == nil else { return }
    guard let controller = currentFlutterViewController() else {
      retryApplePencilInteractionSetup()
      return
    }

    if #available(iOS 12.1, *), applePencilInteractionHandler == nil {
      let handler = ApplePencilInteractionStreamHandler()
      let channel = FlutterEventChannel(
        name: "saber/apple_pencil_interaction/events",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setStreamHandler(handler)
      handler.attach(to: controller.view)
      applePencilInteractionChannel = channel
      applePencilInteractionHandler = handler
    }

    if #available(iOS 13.0, *), applePencilHoverHandler == nil {
      let handler = ApplePencilHoverStreamHandler()
      let channel = FlutterEventChannel(
        name: "saber/apple_pencil_hover/events",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setStreamHandler(handler)
      handler.attach(to: controller.view)
      applePencilHoverChannel = channel
      applePencilHoverHandler = handler
    }

    if applePencilTelemetryHandler == nil {
      let handler = ApplePencilTelemetryStreamHandler()
      let channel = FlutterEventChannel(
        name: "saber/apple_pencil_telemetry/events",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setStreamHandler(handler)
      handler.attach(to: controller.view)
      applePencilTelemetryChannel = channel
      applePencilTelemetryHandler = handler
    }
  }

  private func retryApplePencilInteractionSetup() {
    guard applePencilInteractionSetupAttempts < Self.maxApplePencilInteractionSetupAttempts else {
      print("Apple Pencil interaction setup failed: FlutterViewController was not ready")
      return
    }

    applePencilInteractionSetupAttempts += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.setupApplePencilInteraction()
    }
  }

  private func currentFlutterViewController() -> FlutterViewController? {
    if let controller = findFlutterViewController(in: window?.rootViewController) {
      return controller
    }

    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }

        for window in windowScene.windows {
          if let controller = findFlutterViewController(in: window.rootViewController) {
            return controller
          }
        }
      }
    }

    return nil
  }

  private func findFlutterViewController(in root: UIViewController?) -> FlutterViewController? {
    guard let root else { return nil }

    if let controller = root as? FlutterViewController {
      return controller
    }

    if let controller = findFlutterViewController(in: root.presentedViewController) {
      return controller
    }

    for child in root.children {
      if let controller = findFlutterViewController(in: child) {
        return controller
      }
    }

    return nil
  }
}

private final class ApplePencilTelemetryStreamHandler: NSObject,
  FlutterStreamHandler,
  UIGestureRecognizerDelegate,
  ApplePencilTelemetryGestureRecognizerDelegate
{
  private static let sourceReal = 1
  private static let sourceCoalesced = 1 << 1
  private static let sourcePredicted = 1 << 2
  private static let sourceEstimated = 1 << 3

  private var eventSink: FlutterEventSink?
  private weak var view: UIView?
  private var recognizer: ApplePencilTelemetryGestureRecognizer?

  func attach(to view: UIView) {
    self.view = view

    let recognizer = ApplePencilTelemetryGestureRecognizer()
    recognizer.cancelsTouchesInView = false
    recognizer.delaysTouchesBegan = false
    recognizer.delaysTouchesEnded = false
    recognizer.requiresExclusiveTouchType = false
    recognizer.delegate = self
    recognizer.telemetryDelegate = self
    view.addGestureRecognizer(recognizer)
    self.recognizer = recognizer
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
  }

  func applePencilTelemetryGestureRecognizer(
    _ recognizer: ApplePencilTelemetryGestureRecognizer,
    didReceive touches: Set<UITouch>,
    with event: UIEvent,
    phase: String
  ) {
    guard let view else { return }

    for touch in touches where touch.type == .pencil {
      var payload = Self.payload(
        for: touch,
        in: view,
        phase: phase,
        sourceFlags: Self.sourceReal
      )

      payload["coalesced"] = (event.coalescedTouches(for: touch) ?? [])
        .filter { $0.type == .pencil }
        .map {
          Self.payload(
            for: $0,
            in: view,
            phase: phase,
            sourceFlags: Self.sourceCoalesced
          )
        }

      payload["predicted"] = (event.predictedTouches(for: touch) ?? [])
        .filter { $0.type == .pencil }
        .map {
          Self.payload(
            for: $0,
            in: view,
            phase: "changed",
            sourceFlags: Self.sourcePredicted
          )
        }

      eventSink?(payload)
    }
  }

  private static func payload(
    for touch: UITouch,
    in view: UIView,
    phase: String,
    sourceFlags: Int
  ) -> [String: Any] {
    let location = touch.location(in: view)
    let preciseLocation = touch.preciseLocation(in: view)
    let maximumPossibleForce = touch.maximumPossibleForce
    let force = touch.force
    var flags = sourceFlags

    if touch.estimatedProperties.rawValue != 0 {
      flags |= sourceEstimated
    }

    var payload: [String: Any] = [
      "phase": phase,
      "x": location.x,
      "y": location.y,
      "preciseX": preciseLocation.x,
      "preciseY": preciseLocation.y,
      "timestamp": touch.timestamp,
      "force": force,
      "maximumPossibleForce": maximumPossibleForce,
      "majorRadius": touch.majorRadius,
      "majorRadiusTolerance": touch.majorRadiusTolerance,
      "altitudeAngle": touch.altitudeAngle,
      "azimuthAngle": touch.azimuthAngle(in: view),
      "azimuthUnitX": touch.azimuthUnitVector(in: view).dx,
      "azimuthUnitY": touch.azimuthUnitVector(in: view).dy,
      "estimatedProperties": touch.estimatedProperties.rawValue,
      "estimatedPropertiesExpectingUpdates": touch.estimatedPropertiesExpectingUpdates.rawValue,
      "sourceFlags": flags,
    ]

    if maximumPossibleForce > 0 {
      payload["pressure"] = min(1, max(0, force / maximumPossibleForce))
    }

    if #available(iOS 17.5, *) {
      payload["rollAngle"] = touch.rollAngle
    }

    return payload
  }
}

private protocol ApplePencilTelemetryGestureRecognizerDelegate: AnyObject {
  func applePencilTelemetryGestureRecognizer(
    _ recognizer: ApplePencilTelemetryGestureRecognizer,
    didReceive touches: Set<UITouch>,
    with event: UIEvent,
    phase: String
  )
}

private final class ApplePencilTelemetryGestureRecognizer: UIGestureRecognizer {
  weak var telemetryDelegate: ApplePencilTelemetryGestureRecognizerDelegate?

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    telemetryDelegate?.applePencilTelemetryGestureRecognizer(
      self,
      didReceive: touches,
      with: event,
      phase: "began"
    )
    state = .began
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    telemetryDelegate?.applePencilTelemetryGestureRecognizer(
      self,
      didReceive: touches,
      with: event,
      phase: "changed"
    )
    state = .changed
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    telemetryDelegate?.applePencilTelemetryGestureRecognizer(
      self,
      didReceive: touches,
      with: event,
      phase: "ended"
    )
    state = .ended
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    telemetryDelegate?.applePencilTelemetryGestureRecognizer(
      self,
      didReceive: touches,
      with: event,
      phase: "cancelled"
    )
    state = .cancelled
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
    return false
  }

  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
    return false
  }
}

@available(iOS 13.0, *)
private final class ApplePencilHoverStreamHandler: NSObject,
  FlutterStreamHandler,
  UIGestureRecognizerDelegate
{
  private var eventSink: FlutterEventSink?
  private weak var view: UIView?
  private var hoverRecognizer: UIHoverGestureRecognizer?
  private var emittedActiveHover = false

  func attach(to view: UIView) {
    self.view = view

    let recognizer = UIHoverGestureRecognizer(
      target: self,
      action: #selector(handleHover(_:))
    )
    recognizer.cancelsTouchesInView = false
    recognizer.delaysTouchesBegan = false
    recognizer.delaysTouchesEnded = false
    recognizer.requiresExclusiveTouchType = false
    recognizer.delegate = self
    view.addGestureRecognizer(recognizer)
    hoverRecognizer = recognizer
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
  }

  @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
    guard let view else { return }

    let location = recognizer.location(in: view)
    let phase = Self.phaseName(recognizer.state)
    var payload: [String: Any] = [
      "phase": phase,
      "x": location.x,
      "y": location.y,
    ]

    var zOffset: CGFloat?
    var azimuthAngle: CGFloat?
    var altitudeAngle: CGFloat?
    var rollAngle: CGFloat?

    if #available(iOS 16.1, *) {
      let value = recognizer.zOffset
      zOffset = value
      payload["zOffset"] = value
    }

    if #available(iOS 16.4, *) {
      let azimuth = recognizer.azimuthAngle(in: view)
      let altitude = recognizer.altitudeAngle
      azimuthAngle = azimuth
      altitudeAngle = altitude
      payload["azimuthAngle"] = azimuth
      payload["altitudeAngle"] = altitude
    }

    if #available(iOS 17.5, *) {
      let value = recognizer.rollAngle
      rollAngle = value
      payload["rollAngle"] = value
    }

    let isEnding = phase == "ended" || phase == "cancelled"
    guard isApplePencilHover(
      zOffset: zOffset,
      azimuthAngle: azimuthAngle,
      altitudeAngle: altitudeAngle,
      rollAngle: rollAngle
    ) || (isEnding && emittedActiveHover) else { return }

    emittedActiveHover = !isEnding
    eventSink?(payload)
  }

  private func isApplePencilHover(
    zOffset: CGFloat?,
    azimuthAngle: CGFloat?,
    altitudeAngle: CGFloat?,
    rollAngle: CGFloat?
  ) -> Bool {
    if let zOffset, zOffset > 0 { return true }
    if let altitudeAngle, altitudeAngle > 0 { return true }
    if let azimuthAngle, azimuthAngle != 0 { return true }
    if let rollAngle, rollAngle != 0 { return true }
    return false
  }

  private static func phaseName(_ state: UIGestureRecognizer.State) -> String {
    switch state {
    case .began:
      return "began"
    case .changed:
      return "changed"
    case .ended:
      return "ended"
    case .cancelled, .failed:
      return "cancelled"
    default:
      return "changed"
    }
  }
}

@available(iOS 12.1, *)
private final class ApplePencilInteractionStreamHandler: NSObject,
  FlutterStreamHandler,
  UIPencilInteractionDelegate
{
  private var eventSink: FlutterEventSink?
  private weak var view: UIView?
  private var interaction: UIPencilInteraction?

  func attach(to view: UIView) {
    self.view = view

    let interaction = UIPencilInteraction()
    interaction.delegate = self
    view.addInteraction(interaction)
    self.interaction = interaction
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    send(
      type: "doubleTap",
      preferredAction: Self.preferredTapActionName(),
      phase: "ended"
    )
  }

  @available(iOS 17.5, *)
  func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
    send(
      type: "doubleTap",
      preferredAction: Self.preferredTapActionName(),
      phase: "ended"
    )
  }

  @available(iOS 17.5, *)
  func pencilInteraction(
    _ interaction: UIPencilInteraction,
    didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
  ) {
    send(
      type: "squeeze",
      preferredAction: Self.preferredSqueezeActionName(),
      phase: Self.phaseName(squeeze.phase)
    )
  }

  private func send(type: String, preferredAction: String, phase: String) {
    eventSink?([
      "type": type,
      "preferredAction": preferredAction,
      "phase": phase,
    ])
  }

  private static func preferredTapActionName() -> String {
    actionName(rawValue: UIPencilInteraction.preferredTapAction.rawValue)
  }

  private static func preferredSqueezeActionName() -> String {
    guard #available(iOS 17.5, *) else { return "unknown" }
    return actionName(rawValue: UIPencilInteraction.preferredSqueezeAction.rawValue)
  }

  private static func actionName(rawValue: Int) -> String {
    switch rawValue {
    case 0:
      return "ignore"
    case 1:
      return "switchEraser"
    case 2:
      return "switchPrevious"
    case 3:
      return "showColorPalette"
    case 4:
      return "showInkAttributes"
    case 5:
      return "showContextualPalette"
    case 6:
      return "runSystemShortcut"
    default:
      return "unknown"
    }
  }

  @available(iOS 17.5, *)
  private static func phaseName(_ phase: UIPencilInteraction.Phase) -> String {
    switch phase {
    case .began:
      return "began"
    case .changed:
      return "changed"
    case .ended:
      return "ended"
    case .cancelled:
      return "cancelled"
    @unknown default:
      return "unknown"
    }
  }
}
