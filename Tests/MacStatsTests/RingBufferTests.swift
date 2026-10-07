import Testing
@testable import MacStatsCore

/// Regression cover for the history-trace buffer: capacity clamping,
/// oldest-to-newest ordering, wrap-around overwrite order and the
/// empty/full/cleared edges.
@Suite("RingBuffer")
struct RingBufferTests {

    @Test("capacity below 1 is clamped to 1")
    func capacityIsClampedToAtLeastOne() {
        #expect(RingBuffer<Int>(capacity: 0).capacity == 1)
        #expect(RingBuffer<Int>(capacity: -8).capacity == 1)
        #expect(RingBuffer<Int>(capacity: 8).capacity == 8)
    }

    @Test("a fresh buffer is empty")
    func freshBufferIsEmpty() {
        let buffer = RingBuffer<Int>(capacity: 4)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.values.isEmpty)
        #expect(buffer.last == nil)
    }

    @Test("below capacity keeps insertion order")
    func belowCapacityKeepsInsertionOrder() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(10)
        buffer.append(20)
        buffer.append(30)
        #expect(buffer.count == 3)
        #expect(!buffer.isEmpty)
        #expect(buffer.values == [10, 20, 30])
        #expect(buffer.last == 30)
    }

    @Test("exactly full keeps insertion order")
    func exactlyFullKeepsInsertionOrder() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        #expect(buffer.count == 3)
        #expect(buffer.values == [1, 2, 3])
        #expect(buffer.last == 3)
    }

    @Test("the first overwrite drops the oldest sample")
    func firstOverwriteDropsOldestSample() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        #expect(buffer.count == 3)
        #expect(buffer.values == [2, 3, 4])
        #expect(buffer.last == 4)
    }

    @Test("appending past capacity keeps only the newest samples in order")
    func overwritesOldestSamplesOnceFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 {
            buffer.append(value)
        }
        #expect(buffer.count == 3)
        #expect(buffer.values == [3, 4, 5])
        #expect(buffer.last == 5)
    }

    @Test("capacity 1 keeps only the newest sample")
    func capacityOneKeepsOnlyNewestSample() {
        var buffer = RingBuffer<Int>(capacity: 1)
        buffer.append(1)
        #expect(buffer.count == 1)
        #expect(buffer.values == [1])
        buffer.append(2)
        #expect(buffer.count == 1)
        #expect(buffer.values == [2])
        #expect(buffer.last == 2)
    }

    @Test("order stays correct after many wrap-arounds")
    func orderStaysCorrectAcrossManyWrapArounds() {
        var buffer = RingBuffer<Int>(capacity: 4)
        for value in 1...10 {
            buffer.append(value)
        }
        #expect(buffer.values == [7, 8, 9, 10])
        buffer.append(11)
        #expect(buffer.values == [8, 9, 10, 11])
        #expect(buffer.last == buffer.values.last)
    }

    @Test("removeAll empties the buffer and leaves it reusable")
    func removeAllEmptiesAndKeepsBufferReusable() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 {
            buffer.append(value)
        }
        buffer.removeAll()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.values.isEmpty)
        #expect(buffer.last == nil)
        buffer.append(99)
        #expect(buffer.count == 1)
        #expect(buffer.values == [99])
        #expect(buffer.capacity == 3)
    }

    @Test("non-numeric elements keep the same ordering guarantees")
    func worksWithStringElements() {
        var buffer = RingBuffer<String>(capacity: 2)
        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        #expect(buffer.values == ["b", "c"])
        #expect(buffer.last == "c")
    }
}
