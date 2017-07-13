import PromiseKit
import XCTest

private enum E: Error { case dummy }

class AmbiguityTests: XCTestCase {

    func test1() {
        // verify that Guarantee `then` doesn’t become `Guarantee<Promise<Int>>`
        wait { ex in
            func foo(_: Error) { ex.fulfill() }
            let g = Guarantee().then{ Promise<Int>(error: E.dummy) }.catch{ _ in ex.fulfill() }
        }
    }

    func test2() {
    #if swift(>=4.0)
        do {
            func foo() -> Promise<Int> {
                return Promise {
                    print("hi")
                    return Promise(value: 3)
                }
            }
            _ = foo()
        }

        do {
            func foo() -> Promise<Int> {
                return Promise {
                    Promise(value: 3)
                }
            }

            _ = foo()
        }
    #endif

        do {
            func foo() -> Promise<Int> {
                let bar = Promise(value: 3)
                return firstly {
                    return bar
                }
            }

            _ = foo()
        }

        do {
            firstly {
                return Promise(value: 3)
            }.done {
                XCTAssertEqual($0, 3)
            }
        }

        do {
            firstly {
                Promise(value: 3)
            }.done {
                XCTAssertEqual($0, 3)
            }
        }

        do {
            firstly {
                Guarantee(value: 3)
            }.done {
                XCTAssertEqual($0, 3)
            }
        }
    }

    func test3() {
        let p = after(.milliseconds(10)).then{ Promise(value: 1) }
        XCTAssert(p is Promise<Int>, "\(p)")
    }
}
