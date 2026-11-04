import Flutter
import UIKit
import UniformTypeIdentifiers
import XCTest


@testable import adaptive_liquid_glass

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = AdaptiveLiquidGlassPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}

actor ConcurrencyProbe {
  private(set) var current = 0
  private(set) var peak = 0
  func enter() { current += 1; peak = max(peak, current) }
  func leave() { current -= 1 }
}

final class ImportSchedulingTests: XCTestCase {
  func testLimiterNeverExceedsLimit() async throws {
    let limiter = AsyncLimiter(limit: 3)
    let probe = ConcurrencyProbe()
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<20 {
        group.addTask {
          try await limiter.run {
            await probe.enter()
            try await Task.sleep(nanoseconds: 5_000_000)
            await probe.leave()
          }
        }
      }
      try await group.waitForAll()
    }
    let peak = await probe.peak
    XCTAssertEqual(peak, 3)
  }

  func testCancelledWaiterThrowsAndFreesNoPermit() async throws {
    let limiter = AsyncLimiter(limit: 1)
    try await limiter.acquire()
    let waiter = Task { try await limiter.acquire() }
    try await Task.sleep(nanoseconds: 10_000_000)
    waiter.cancel()
    do {
      try await waiter.value
      XCTFail("expected CancellationError")
    } catch is CancellationError {}
    await limiter.release()
    try await limiter.acquire() // the permit is free again
  }

  func testOrderedResultsRestoreSelectionOrder() {
    var results = OrderedResults<String>(count: 4)
    results.set(2, "c")
    results.set(0, "a")
    results.set(3, "d") // index 1 failed
    XCTAssertEqual(results.inOrder, ["a", "c", "d"])
  }

  func testThrottleAllowsTenPerSecondPlusFinal() {
    var throttle = ProgressThrottle(interval: 0.1)
    XCTAssertTrue(throttle.allow(now: 0, final: false))
    XCTAssertFalse(throttle.allow(now: 0.05, final: false))
    XCTAssertTrue(throttle.allow(now: 0.06, final: true))
    XCTAssertFalse(throttle.allow(now: 0.1, final: false))
    XCTAssertTrue(throttle.allow(now: 0.16, final: false))
  }
}

final class PhotosCopyShareTests: XCTestCase {
  private func share(_ args: [String: Any], video: Bool = false, _ type: UTType = .jpeg) -> Double {
    GlassPhotosPicker.copyShare(isVideo: video, type: type, options: .init(args))
  }

  func testImagesWithoutConversionCopyCoversTheWholeItem() {
    XCTAssertEqual(share([:]), 1.0)
    XCTAssertEqual(share(["compatibleFormat": true], .jpeg), 1.0)
    XCTAssertEqual(share(["compatibleFormat": true], .png), 1.0)
  }

  func testImagesThatConvertSplitCopyAndConversion() {
    XCTAssertEqual(share(["maxWidth": 100]), 0.5)
    XCTAssertEqual(share(["maxHeight": 100]), 0.5)
    XCTAssertEqual(share(["imageQuality": 80]), 0.5)
    XCTAssertEqual(share(["compatibleFormat": true], .heic), 0.5)
    XCTAssertEqual(share(["compatibleFormat": true], .heif), 0.5)
    XCTAssertEqual(share([:], .heic), 1.0)
  }

  /// The codec is unknown before the copy, so compatible videos assume an export.
  func testVideosSplitOnlyWhenCompatible() {
    XCTAssertEqual(share([:], video: true, .movie), 1.0)
    XCTAssertEqual(share(["maxWidth": 100, "imageQuality": 50], video: true, .movie), 1.0)
    XCTAssertEqual(share(["compatibleFormat": true], video: true, .movie), 0.5)
  }
}

final class RisingFractionTests: XCTestCase {
  func testReportsRisesOfAtLeastOnePercentAndNeverFalls() {
    var gate = RisingFraction()
    XCTAssertFalse(gate.allow(0))
    XCTAssertFalse(gate.allow(0.005))
    XCTAssertTrue(gate.allow(0.01))
    XCTAssertFalse(gate.allow(0.015))
    XCTAssertTrue(gate.allow(0.5))
    XCTAssertFalse(gate.allow(0.3)) // out of order: never backwards
    XCTAssertFalse(gate.allow(0.505))
    XCTAssertTrue(gate.allow(0.999))
    XCTAssertTrue(gate.allow(1)) // completion always passes once
    XCTAssertFalse(gate.allow(1))
  }
}

/// Presentation timing for the picker: the reply waits for the dismissal,
/// and a new presentation waits for a running transition.
/// Records whether each presentation started while a transition was running.
final class RecordingController: UIViewController {
  private(set) var presentedMidTransition: [Bool] = []

  override func present(
    _ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil
  ) {
    presentedMidTransition.append(transitionCoordinator != nil)
    super.present(controller, animated: animated, completion: completion)
  }
}

@MainActor
final class PickerPresentationTests: XCTestCase {
  private var window: UIWindow!
  private var root: RecordingController!

  override func setUp() async throws {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    window = UIWindow(windowScene: try XCTUnwrap(scene))
    root = RecordingController()
    window.rootViewController = root
    window.makeKeyAndVisible()
  }

  override func tearDown() async throws {
    window.isHidden = true
    window = nil
    root = nil
  }

  private func presented(_ controller: UIViewController) async {
    await withCheckedContinuation { done in
      root.present(controller, animated: true) { done.resume() }
    }
  }

  private func waitUntil(_ condition: @escaping () -> Bool) async {
    let deadline = Date().addingTimeInterval(5)
    while !condition() && Date() < deadline {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  func testReplyWaitsForTheDismissalToEnd() async {
    let child = UIViewController()
    await presented(child)
    var replied = false
    var settled = false
    GlassPhotosPicker.dismissThen(child) {
      replied = true
      settled = child.presentingViewController == nil && self.root.presentedViewController == nil
    }
    XCTAssertFalse(replied)
    await waitUntil { replied }
    XCTAssertTrue(replied)
    XCTAssertTrue(settled)
  }

  func testAnUnpresentedControllerRepliesAtOnce() {
    var count = 0
    GlassPhotosPicker.dismissThen(nil) { count += 1 }
    GlassPhotosPicker.dismissThen(UIViewController()) { count += 1 }
    XCTAssertEqual(count, 2)
  }

  func testDismissDuringThePresentationStillReplies() async {
    let child = UIViewController()
    root.present(child, animated: true)
    var replied = false
    GlassPhotosPicker.dismissThen(child) { replied = true }
    await waitUntil { replied }
    XCTAssertTrue(replied)
    XCTAssertNil(root.presentedViewController)
  }

  func testPresentWaitsForARunningDismissal() async {
    let first = UIViewController()
    await presented(first)
    root.dismiss(animated: true)
    let second = UIViewController()
    XCTAssertNotNil(root.transitionCoordinator)
    GlassPhotosPicker.presentWhenSettled(second, from: root) { false }
    XCTAssertFalse(root.presentedViewController === second)
    await waitUntil { self.root.presentedViewController === second }
    XCTAssertTrue(root.presentedViewController === second)
    // [first] then [second]; [second] only once the dismissal had ended.
    XCTAssertEqual(root.presentedMidTransition, [false, false])
  }

  func testPresentIsSkippedWhenFinishedMeanwhile() async {
    let first = UIViewController()
    await presented(first)
    var dismissed = false
    root.dismiss(animated: true) { dismissed = true }
    var finished = false
    GlassPhotosPicker.presentWhenSettled(UIViewController(), from: root) { finished }
    finished = true // e.g. a cancel while waiting
    await waitUntil { dismissed }
    try? await Task.sleep(nanoseconds: 300_000_000)
    XCTAssertNil(root.presentedViewController)
  }
}
