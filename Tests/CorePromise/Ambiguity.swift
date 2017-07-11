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
                    print("hi")
                    return bar
                }
            }

            _ = foo()
        }

        do {
            firstly {
                print("hi")
                return Promise(value: 3)
            }.then {
                XCTAssertEqual($0, 3)
            }
        }

        do {
            firstly {
                Promise(value: 3)
            }.then {
                XCTAssertEqual($0, 3)
            }
        }
    }
}
