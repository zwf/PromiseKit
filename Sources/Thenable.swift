import class Foundation.Thread
import Dispatch

public protocol Thenable: class {
    associatedtype T
    func pipe(to: @escaping (Result<T>) -> Void)
    var result: Result<T>? { get }
}

public extension Thenable {
    func then<U: Thenable>(on: ExecutionContext? = NextMainRunloopContext(), execute body: @escaping (T) throws -> U) -> Promise<U.T> {
        let promise = Promise<U.T>(.pending)
        pipe { result in
            switch result {
            case .fulfilled(let value):
                go(on) {
                    do {
                        let intermediary = try body(value)
                        guard intermediary !== promise else { throw PMKError.returnedSelf }
                        intermediary.pipe{ promise.schrödinger = .resolved($0) }
                    } catch {
                        promise.schrödinger = .resolved(.rejected(error))
                    }
                }
            case .rejected(let error):
                promise.schrödinger = .resolved(.rejected(error))
            }
        }
        return promise
    }

    func then<U>(on: ExecutionContext? = NextMainRunloopContext(), execute body: @escaping (T) throws -> U) -> Promise<U> {
        let promise = Promise<U>(.pending)
        pipe { result in
            switch result {
            case .fulfilled(let value):
                go(on) {
                    let result: Result<U>
                    do {
                        let value = try body(value)
                        result = .fulfilled(value)
                    } catch {
                        result = .rejected(error)
                    }
                    promise.schrödinger = .resolved(result)
                }
            case .rejected(let error):
                promise.schrödinger = .resolved(.rejected(error))
            }
        }
        return promise
    }

    /**
     Allows you to validate properties of the current value. The promise you
     return will fail the chain if it is rejected. Otherwise the input value
     is returned to the chain.
     */
    func validate(on: ExecutionContext? = NextMainRunloopContext(), _ body: @escaping (T) -> Promise<Void>) -> Promise<T> {
        let promise = Promise<T>(.pending)
        pipe { result in
            switch result {
            case .fulfilled(let value):
                body(value).pipe { result in
                    switch result {
                    case .rejected(let error):
                        promise.schrödinger = .resolved(.rejected(error))
                    case .fulfilled:
                        promise.schrödinger = .resolved(.fulfilled(value))
                    }
                }
            case .rejected(let error):
                promise.schrödinger = .resolved(.rejected(error))
            }
        }
        return promise
    }

    func asVoid() -> Promise<Void> {
        //TODO zalgo this
        return then{ _ in }
    }

    /**
     Blocks this thread, so you know, don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    public func wait() throws -> T {

        if Thread.isMainThread {
            print("PromiseKit: warning: `wait()` called on main thread!")
        }

        var result = self.result

        if result == nil {
            let group = DispatchGroup()
            group.enter()
            pipe { result = $0; group.leave() }
            group.wait()
        }

        switch result! {
        case .rejected(let error):
            throw error
        case .fulfilled(let value):
            return value
        }
    }
}


public extension Thenable {
    func tap(_ body: @escaping (Result<T>) -> Void = { print("PromiseKit:", $0) }) -> Self {
        pipe(to: body)
        return self
    }

    var value: T? {
        switch result {
        case .fulfilled(let value)?:
            return value
        case .rejected?, nil:
            return nil
        }
    }

    var isFulfilled: Bool {
        switch result {
        case .fulfilled?:
            return true
        case .rejected?, nil:
            return false
        }
    }

    var isRejected: Bool {
        switch result {
        case .rejected?:
            return true
        case .fulfilled?, nil:
            return false
        }
    }

    var isPending: Bool {
        switch result {
        case .fulfilled?, .rejected?:
            return false
        case nil:
            return true
        }
    }

    var isResolved: Bool {
        switch result {
        case .fulfilled?, .rejected?:
            return true
        case nil:
            return false
        }
    }
}



public extension Thenable where T: Sequence {
    /**
     Transforms a `Promise` where `T` is a `Collection` into a `Promise<[U]>`

         func download(urls: [String]) -> Promise<UIImage> {
             //…
         }

         return URLSession.shared.dataTask(url: url).asArray().map(download)

     Equivalent to:

         func download(urls: [String]) -> Promise<UIImage> {
             //…
         }

         return URLSession.shared.dataTask(url: url).then { urls in
             return when(fulfilled: urls.map(download))
         }


     - Note:
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter transform: The closure that executes when this promise resolves.
     - Returns: A new promise, resolved with this promise’s resolution.
     - TODO: allow concurrency
     */
    func map<U>(on: ExecutionContext? = NextMainRunloopContext(), file: StaticString = #file, line: UInt = #line, transform: @escaping (T.Iterator.Element) throws -> Promise<U>) -> Promise<[U]> {
        return then(on: on) {
            return when(fulfilled: try $0.map(transform))
        }
    }

    func map<U>(on: ExecutionContext? = NextMainRunloopContext(), transform: @escaping (T.Iterator.Element) throws -> U) -> Promise<[U]> {
        return then(on: on){ try $0.map(transform) }
    }

    /// `nil` rejects the resulting promise with `PMKError.flatMap`
    func flatMap<U>(on: ExecutionContext? = NextMainRunloopContext(), _ transform: @escaping (T.Iterator.Element) -> U?) -> Promise<[U]> {
        return then(on: on) { values in
            return try values.map { value in
                guard let result = transform(value) else {
                    throw PMKError.flatMap(value, U.self)
                }
                return result
            }
        }
    }

    func flatMap<U>(on: ExecutionContext? = NextMainRunloopContext(), _ transform: @escaping (T.Iterator.Element) -> Promise<[U]>) -> Promise<[U]> {
        return then(on: on) { values in
            return when(fulfilled: values.map(transform)).then(on: nil) {
                $0.flatMap{ $0 }
            }
        }
    }

    func filter(on: ExecutionContext? = NextMainRunloopContext(), test: @escaping (T.Iterator.Element) -> Bool) -> Promise<[T.Iterator.Element]> {
        return then(on: on) {
            return $0.filter(test)
        }
    }

    func forEach(on: ExecutionContext? = NextMainRunloopContext(), _ body: @escaping (T.Iterator.Element) -> Void) -> Promise<T> {
        return then(on: on) {
            $0.forEach(body)
            return $0
        }
    }
}

public extension Thenable where T: Collection {
    var first: Promise<T.Iterator.Element> {
        return then { aa in
            if let a1 = aa.first {
                return a1
            } else {
                throw PMKError.badInput
            }
        }
    }

    var last: Promise<T.Iterator.Element> {
        return then { aa in
            if aa.isEmpty {
                throw PMKError.badInput
            } else {
                let i = aa.index(aa.endIndex, offsetBy: -1)
                return aa[i]
            }
        }
    }
}

public extension Thenable where T: Sequence, T.Iterator.Element: Comparable {
    func sorted(on: ExecutionContext? = NextMainRunloopContext()) -> Promise<[T.Iterator.Element]> {
        return then(on: on){ $0.sorted() }
    }
}

public extension Thenable {
    /**
     Transforms the value of this promise using the provided function.

     If the result is nil, rejects the returned promise with `PMKError.flatMap`.

     - Remark: Essentially, this is a more specific form of `then` which errors for `nil`.
     - Remark: This function is useful for parsing eg. JSON.
     */
    func flatMap<U>(_ transform: @escaping (T) throws -> U?) -> Promise<U> {
        return then(on: nil) { value in
            guard let result = try transform(value) else {
                throw PMKError.flatMap(value, U.self)
            }
            return result
        }
    }
}
