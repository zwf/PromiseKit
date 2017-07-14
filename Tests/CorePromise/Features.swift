import PromiseKit
import XCTest

class FeatureFlatMapTests: XCTestCase {
    func testPromise() {
        let foo: Any? = ["a": 1]

        wait { ex in
            Promise(value: foo).flatMap{ $0 as? [String: Any] }.done {
                XCTAssertEqual($0["a"] as? Int, 1)
                ex.fulfill()
            }
        }
    }

    func testGuarantee() {
        let foo: Any? = ["a": 1]

        wait { ex in
            Guarantee(value: foo).flatMap{ $0 as? [String: Any] }.done {
                XCTAssertEqual($0["a"] as? Int, 1)
                ex.fulfill()
            }
        }
    }
}


class FeatureAfterTests: XCTestCase {
    func testZero() {
        wait { ex in
            after(.seconds(0)).done(execute: ex.fulfill)
        }
    }

    func testNegative() {
        wait { ex in
            after(.seconds(-1)).done(execute: ex.fulfill)
        }
    }

    func testPositive() {
        wait { ex in
            after(.seconds(1)).done(execute: ex.fulfill)
        }
    }
}


class FeatureRaceTests: XCTestCase {
    func testCompilationAmbiguity() {
        let p1 = after(.milliseconds(10)).then{ Guarantee(value: 1) }
        let p2 = after(.milliseconds(10)).then{ Guarantee(value: 1) }

        let p3 = race([p1, p2])
        let p4 = race(p1, p2)

        XCTAssert(p1 is Guarantee<Int>)
        XCTAssert(p2 is Guarantee<Int>)
        XCTAssert(p3 is Promise<Int>)  // no array form because can't handle empty array input
        XCTAssert(p4 is Guarantee<Int>)

        let p5: Promise<Int> = after(.milliseconds(10)).map{ 1 }
        let p6: Promise<Int> = after(.milliseconds(10)).map{ 1 }

        let p7 = race([p5, p6])
        let p8 = race(p5, p6)

        XCTAssert(p5 is Promise<Int>)
        XCTAssert(p6 is Promise<Int>)
        XCTAssert(p7 is Promise<Int>)
        XCTAssert(p8 is Promise<Int>)
    }

    func testSomeoneWins() {
        let p1: Promise<Int> = after(.milliseconds(200)).map{ 1 }
        let p2: Promise<Int> = Promise{ _ in }

        wait { ex in
            race(p1, p2).done { value in
                XCTAssertEqual(value, 1)
                ex.fulfill()
            }
        }
    }
}

class FeatureWhenTests: XCTestCase {
    func testEmpty() {
        wait { ex in
            let input = Array<Promise<Int>>()
            when(fulfilled: input).done{ _ in ex.fulfill() }
        }
    }
}
