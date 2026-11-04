import Foundation

/// An async semaphore: at most `limit` bodies run at once. Waiters are
/// served in order and leave the queue when their task is cancelled.
actor AsyncLimiter {
  private let limit: Int
  private var running = 0
  private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

  init(limit: Int) {
    precondition(limit > 0)
    self.limit = limit
  }

  func acquire() async throws {
    try Task.checkCancellation()
    if running < limit {
      running += 1
      return
    }
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else {
          waiters.append((id, continuation))
        }
      }
    } onCancel: {
      Task { await self.dropWaiter(id) }
    }
  }

  /// Hands the permit to the next waiter, or frees it.
  func release() {
    if waiters.isEmpty {
      running -= 1
    } else {
      waiters.removeFirst().continuation.resume()
    }
  }

  private func dropWaiter(_ id: UUID) {
    guard let i = waiters.firstIndex(where: { $0.id == id }) else { return }
    waiters.remove(at: i).continuation.resume(throwing: CancellationError())
  }

  nonisolated func run<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> T {
    try await acquire()
    do {
      let value = try await body()
      await release()
      return value
    } catch {
      await release()
      throw error
    }
  }
}

/// Collects results that finish in any order and returns them in selection
/// order, skipping items that failed.
struct OrderedResults<T> {
  private var slots: [T?]

  init(count: Int) { slots = Array(repeating: nil, count: count) }

  mutating func set(_ index: Int, _ value: T) { slots[index] = value }

  var inOrder: [T] { slots.compactMap { $0 } }
}

/// At most one event per `interval`, except final events, which always pass.
struct ProgressThrottle {
  let interval: TimeInterval
  private var last = -TimeInterval.infinity

  init(interval: TimeInterval = 0.1) { self.interval = interval }

  mutating func allow(now: TimeInterval, final: Bool) -> Bool {
    guard final || now - last >= interval else { return false }
    last = now
    return true
  }
}

/// Passes a load's fraction only when it has risen by at least `step`, or
/// reaches 1 for the first time, so the reported value only rises and KVO
/// bursts do not flood the main actor.
struct RisingFraction {
  let step: Double
  private var lastSent = 0.0

  init(step: Double = 0.01) { self.step = step }

  mutating func allow(_ fraction: Double) -> Bool {
    guard fraction > lastSent, fraction >= lastSent + step || fraction >= 1 else { return false }
    lastSent = fraction
    return true
  }
}
