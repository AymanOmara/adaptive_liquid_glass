import Flutter
import UIKit
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
