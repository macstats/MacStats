import Foundation

/// Fixed-capacity ring buffer used for history traces.
///
/// The previous implementation used `Array.removeFirst()` on every tick,
/// which shifts every element (O(n) per sample). This keeps append O(1)
/// and only materialises an ordered array when a view actually needs one.
struct RingBuffer<Element> {
    private var storage: [Element] = []
    private var head = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = Swift.max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    private(set) var count = 0

    var isEmpty: Bool { count == 0 }
    var last: Element? {
        guard count > 0 else { return nil }
        return storage[(head - 1 + capacity) % capacity]
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
        }
        head = (head + 1) % capacity
        count = Swift.min(count + 1, capacity)
    }

    /// Elements from oldest to newest.
    var values: [Element] {
        guard count == capacity else { return storage }
        return Array(storage[head...]) + Array(storage[..<head])
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
        count = 0
    }
}
