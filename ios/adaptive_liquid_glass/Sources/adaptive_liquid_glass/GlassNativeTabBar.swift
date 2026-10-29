import Flutter
import UIKit

final class GlassNativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassNativeTabBar(frame: frame, id: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger)
  }
}

/// The whole system control owns its labels and interactive lens. Flutter
/// retains selection state; unsupported/custom layouts use the Flutter bar.
private final class GlassNativeTabBar: NSObject, FlutterPlatformView {
  private let root: NativeTabRoot
  private let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger) {
    root = NativeTabRoot(frame: frame)
    channel = FlutterMethodChannel(name: "adaptive_liquid_glass/native_tabs_\(id)", binaryMessenger: messenger)
    super.init()
    _ = root.configure(arguments)
    root.onSelected = { [weak self] index, event in
      self?.channel.invokeMethod("selected", arguments: index) { [weak self] response in
        guard let self, self.root.event == event, let index = response as? Int else { return }
        self.root.select(index)
      }
    }
    root.onUnsupported = { [weak self] in self?.channel.invokeMethod("unsupported", arguments: nil) }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "update": result(self.root.configure(call.arguments as? [String: Any] ?? [:]))
      #if DEBUG
      case "debugState": result(self.root.debugState())
      case "debugSelect": self.root.debugSelect(call.arguments as? Int ?? -1); result(nil)
      #endif
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  func view() -> UIView { root }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class NativeTabRoot: UIView, UITabBarControllerDelegate {
  private var controller: UITabBarController?
  private var content: [[String: Any]] = []
  private var templates: [Data: UIImage] = [:]
  private var templateScale: CGFloat = 1
  private var itemRevision = 0
  private var dark: Bool?
  private var pending: [String: Any] = [:]
  private var frames = 0
  private var link: CADisplayLink?
  private var overhang: CGFloat = 24
  private var reportedLayout = false
  private(set) var event = 0
  var onSelected: ((Int, Int) -> Void)?
  var onUnsupported: (() -> Void)?

  override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func configure(_ args: [String: Any]) -> Bool {
    guard !reportedLayout else { return false }
    guard #available(iOS 26.0, *), let items = args["items"] as? [[String: Any]],
          (2...5).contains(items.count) else { return false }
    let scale = (args["imageScale"] as? NSNumber)?.doubleValue ?? 1
    guard scale.isFinite, scale > 0 else { return false }
    if templateScale != scale { templates.removeAll(); templateScale = scale }
    let used = Set(items.flatMap { item in ["image", "activeImage"].compactMap {
      (item[$0] as? FlutterStandardTypedData)?.data
    } })
    templates = templates.filter { used.contains($0.key) }
    guard items.allSatisfy({ item in
      guard image(item, selected: false) != nil else { return false }
      let hasActive = item["activeSymbol"] is String || item["activeImage"] is FlutterStandardTypedData
      return !hasActive || image(item, selected: true) != nil
    }) else { return false }
    // A newer app configuration wins over an in-flight selection reply.
    event += 1
    let nextDark = args["dark"] as? Bool ?? false
    overhang = args["overhang"] as? Double ?? 24
    pending = args
    if controller == nil || dark != nextDark {
      detach()
      controller = nil
      dark = nextDark
      settle()
    } else if let controller { apply(args, to: controller, replaceItems: false) }
    return true
  }

  private func image(_ item: [String: Any], selected: Bool) -> UIImage? {
    if let name = item[selected ? "activeSymbol" : "symbol"] as? String {
      return UIImage(systemName: name)
    }
    guard let data = (item[selected ? "activeImage" : "image"] as? FlutterStandardTypedData)?.data else { return nil }
    if let cached = templates[data] { return cached }
    guard let decoded = UIImage(data: data, scale: templateScale) else { return nil }
    let template = decoded.withRenderingMode(.alwaysTemplate)
    templates[data] = template
    return template
  }

  private func apply(_ args: [String: Any], to host: UITabBarController, replaceItems: Bool) {
    let items = args["items"] as? [[String: Any]] ?? []
    host.view.semanticContentAttribute = (args["rtl"] as? Bool ?? false) ? .forceRightToLeft : .forceLeftToRight
    host.tabBar.semanticContentAttribute = host.view.semanticContentAttribute
    if let argb = args["tint"] as? Int64 {
      host.view.tintColor = UIColor(red: Double((argb >> 16) & 255) / 255,
        green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255,
        alpha: Double((argb >> 24) & 255) / 255)
    } else { host.view.tintColor = .systemBlue }
    if !NSDictionary(dictionary: ["items": content]).isEqual(to: ["items": items]) || replaceItems {
      itemRevision += 1
      host.viewControllers = items.enumerated().map { index, item in
        let child = UIViewController()
        child.view.backgroundColor = .clear
        child.tabBarItem = UITabBarItem(title: item["label"] as? String ?? "",
          image: image(item, selected: false),
          selectedImage: image(item, selected: true))
        child.tabBarItem.tag = index
        child.tabBarItem.badgeValue = item["badge"] as? String
        return child
      }
      content = items
    }
    select(args["selectedIndex"] as? Int ?? 0)
    setNeedsLayout()
  }

  func select(_ index: Int) {
    guard let controller, let children = controller.viewControllers, children.indices.contains(index) else { return }
    if controller.selectedIndex != index { controller.selectedIndex = index }
  }

  private var owner: UIViewController? {
    var responder: UIResponder? = next
    while let current = responder {
      if let vc = current as? UIViewController { return vc }
      responder = current.next
    }
    return nil
  }

  private func attach() {
    guard let controller, window != nil else { return }
    if controller.parent == nil, let owner {
      owner.addChild(controller)
      addSubview(controller.view)
      controller.didMove(toParent: owner)
    } else if controller.view.superview == nil { addSubview(controller.view) }
    setNeedsLayout()
  }

  private func detach() {
    guard let controller else { return }
    controller.delegate = nil
    if controller.parent != nil { controller.willMove(toParent: nil) }
    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }

  private var plainGeometry: Bool {
    var ancestor: UIView? = self
    while let view = ancestor {
      var transform = view.layer.transform
      // Positioning is supported; scaled, skewed and perspective layouts
      // retain Flutter's renderer rather than changing the system viewport.
      transform.m41 = 0
      transform.m42 = 0
      if !CATransform3DIsIdentity(transform) { return false }
      ancestor = view.superview
    }
    return true
  }

  private func unsupported() {
    guard !reportedLayout else { return }
    reportedLayout = true
    controller?.view.isHidden = true
    onUnsupported?()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let window, let controller else { return }
    // Flutter can attach the UIView before assigning its first layout frame.
    // That transient zero-sized frame is not an unsupported placement.
    guard bounds.width > overhang * 2, bounds.height > overhang * 2 else { return }
    guard plainGeometry else { unsupported(); return }
    // Keep the system controller in the real window's coordinate system.
    // Its own layout chooses the floating capsule's geometry and material.
    let frame = convert(window.bounds, from: window)
    if controller.view.frame != frame { controller.view.frame = frame }
    controller.view.layoutIfNeeded()
    let bar = controller.tabBar.convert(controller.tabBar.bounds, to: window)
    let target = convert(bounds.insetBy(dx: overhang, dy: overhang), to: window)
    // A control deliberately placed away from the system's bottom position
    // retains the Flutter implementation, rather than painting elsewhere.
    if !reportedLayout && (abs(bar.midX - target.midX) > 1 || abs(bar.minY - target.minY) > 2) {
      unsupported()
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { link?.invalidate(); link = nil; detach() }
    else {
      detach()
      controller = nil
      settle()
    }
  }

  private func settle() {
    link?.invalidate(); link = nil; frames = 0
    guard window != nil, !pending.isEmpty else { return }
    link = CADisplayLink(target: self, selector: #selector(tick))
    link?.add(to: .main, forMode: .common)
  }

  @objc private func tick() {
    frames += 1
    guard frames >= 3 else { return }
    link?.invalidate(); link = nil
    // Defer creating the material until the new Flutter backdrop is painted.
    let host = UITabBarController()
    host.overrideUserInterfaceStyle = dark == true ? .dark : .light
    if #available(iOS 17.0, *) {
      host.traitOverrides.horizontalSizeClass = .compact
      host.traitOverrides.verticalSizeClass = .regular
    }
    host.view.backgroundColor = .clear
    host.delegate = self
    controller = host
    apply(pending, to: host, replaceItems: true)
    attach()
  }

  func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    guard controller === tabBarController,
          let index = tabBarController.viewControllers?.firstIndex(of: viewController) else { return }
    event += 1
    onSelected?(index, event)
  }
  #if DEBUG
  func debugSelect(_ index: Int) {
    guard let controller, let children = controller.viewControllers, children.indices.contains(index) else { return }
    select(index)
    tabBarController(controller, didSelect: children[index])
  }
  #endif
  func debugState() -> [String: Any] {
    ["selectedIndex": controller?.selectedIndex ?? -1,
     "visible": controller?.view.superview != nil, "dark": dark ?? false,
     "items": content.count, "attached": window != nil,
     "hidden": controller?.view.isHidden ?? false,
     "templateCount": templates.count, "itemRevision": itemRevision,
     "imageWidths": controller?.viewControllers?.map { $0.tabBarItem.image?.size.width ?? 0 } ?? [],
     "activeImageWidths": controller?.viewControllers?.map { $0.tabBarItem.selectedImage?.size.width ?? 0 } ?? [],
     "layoutRejected": reportedLayout,
     "contained": controller?.parent != nil]
  }
  deinit { link?.invalidate(); detach() }
}
