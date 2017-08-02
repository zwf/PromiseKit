import class Foundation.Thread
import Dispatch

public class Guarantee<T>: Thenable {
    let box: Box<T>

    public init(value: T) {
        box = SealedBox(value: value)
    }

    public init(resolver body: (@escaping(T) -> Void) -> Void) {
        box = EmptyBox()
        body(box.seal)
    }

    public func pipe(to: @escaping(Result<T>) -> Void) {
        pipe{ to(.fulfilled($0)) }
    }

    func pipe(to: @escaping(T) -> Void) {
        switch box.inspect() {
        case .pending:
            box.inspect {
                switch $0 {
                case .pending(let handlers):
                    handlers.append(to)
                case .resolved(let value):
                    to(value)
                }
            }
        case .resolved(let value):
            to(value)
        }
    }

    public var result: Result<T>? {
        switch box.inspect() {
        case .pending:
            return nil
        case .resolved(let value):
            return .fulfilled(value)
        }
    }

    init(_: PendingInitializer) {
        box = EmptyBox()
    }

    public class func pending() -> (guarantee: Guarantee<T>, resolver: (T) -> Void) {
        let rg = Guarantee<T>(.pending)
        return (rg, rg.box.seal)
    }
}

public extension Guarantee {
    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, _ body: @escaping(T) -> Void) -> Guarantee<Void> {
        let rg = Guarantee<Void>(.pending)
        pipe { (value: T) in
            on.async {
                body(value)
                rg.box.seal(())
            }
        }
        return rg
    }

    func map<U>(on: DispatchQueue? = conf.Q.map, _ body: @escaping(T) -> U) -> Guarantee<U> {
        let rg = Guarantee<U>(.pending)
        pipe { value in
            on.async {
                rg.box.seal(body(value))
            }
        }
        return rg
    }

    func then<U>(on: DispatchQueue? = conf.Q.map, _ body: @escaping(T) -> Guarantee<U>) -> Guarantee<U> {
        let rg = Guarantee<U>(.pending)
        pipe { value in
            on.async {
                body(value).pipe(to: rg.box.seal)
            }
        }
        return rg
    }

    public func asVoid() -> Guarantee<Void> {
        return map(on: nil) { _ in }
    }
    
    /**
     Blocks this thread, so you know, don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    public func wait() -> T {

        if Thread.isMainThread {
            print("PromiseKit: warning: `wait()` called on main thread!")
        }

        var result = value

        if result == nil {
            let group = DispatchGroup()
            group.enter()
            pipe { (foo: T) in result = foo; group.leave() }
            group.wait()
        }
        
        return result!
    }
}

#if swift(>=3.1)
extension Guarantee where T == Void {
    convenience init() {
        self.init(value: Void())
    }
}
#endif
