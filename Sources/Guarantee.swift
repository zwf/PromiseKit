import Dispatch

/** - Remark: much like a real-life guarantee, it is only as reliable as the source; “promises”
 may never resolve, it is up to the thing providing you the promise to ensure that they do.
 Generally it is considered bad programming for a promise provider to provide a promise that
 never resolves. In real life a guarantee may not be met by eg. World War III, so think
 similarly.
 */
public final class Guarantee<T>: Thenable, Mixin {

    let barrier = DispatchQueue(label: "org.promisekit.barrier", attributes: .concurrent)
    var _schrödinger: Schrödinger<T>

    /**
      - See: `Guarantee()` for a resolved `Void` Guarantee.
      - Remark: We would like `Guarantee(1)` to be the syntax. It makes sense as a wrapper: like
        `Optional`. However this would make `init(sealant:` mistakenly invoke this initializer sometimes. Since
        it could be the `value`. We could work around this by making `Guarantee(.foo) { }` the form of that
        initializer, and we did for a time. But since Swift 4’s tuplegate is a thing, there's no point.
     */
    public init(value: T) {
        _schrödinger = .resolved(value)
    }

    public init(sealant body: (@escaping (T) -> Void) -> Void) {
        _schrödinger = .pending(Handlers())
        body { self.schrödinger = .resolved($0) }
    }

    private init(schrödinger: Schrödinger<T>) {
        _schrödinger = schrödinger
    }

    public static func pending() -> (Guarantee<T>, (T) -> Void) {
        let g = Guarantee<T>(schrödinger: .pending(Handlers()))
        return (g, { g.schrödinger = .resolved($0) })
    }

    public func pipe(to body: @escaping (Result<T>) -> Void) {
        pipe(to: { body(.fulfilled($0)) })
    }

    public var result: Result<T>? {
        switch schrödinger {
        case .pending:
            return nil
        case .resolved(let value):
            return .fulfilled(value)
        }
    }
}

extension Guarantee {
    @discardableResult
    public func then<U>(on: ExecutionContext = NextMainRunloopContext(), execute body: @escaping (T) -> Guarantee<U>) -> Guarantee<U> {
        let (guarantee, seal) = Guarantee<U>.pending()
        pipe { value in
            on.pmkAsync {
                body(value).pipe(to: seal)
            }
        }
        return guarantee
    }

    /// -Remark: not `then` due to Swift ambiguity
    @discardableResult
    public func map<U>(on: ExecutionContext = NextMainRunloopContext(), execute body: @escaping (T) -> U) -> Guarantee<U> {
        let (guarantee, seal) = Guarantee<U>.pending()
        pipe { value in
            on.pmkAsync {
                seal(body(value))
            }
        }
        return guarantee
    }

    /// -Remark: not `then` due to Swift ambiguity
    @discardableResult
    func done(on: ExecutionContext = NextMainRunloopContext(), execute body: @escaping (T) -> Void) -> Guarantee<Void> {
        return map(on: on, execute: body)
    }
}

public extension Guarantee where T == Void {
    convenience init() {
        self.init(value: ())
    }
}
