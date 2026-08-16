import Foundation

final class CancellableTaskHandle: @unchecked Sendable {
  private let lock = NSLock()
  private var task: Task<Void, Never>?

  var hasTask: Bool {
    lock.lock()
    defer { lock.unlock() }
    return task != nil
  }

  func store(_ task: Task<Void, Never>?) {
    lock.lock()
    let previous = self.task
    self.task = task
    lock.unlock()
    previous?.cancel()
  }

  func cancel() {
    lock.lock()
    let task = self.task
    self.task = nil
    lock.unlock()
    task?.cancel()
  }
}
