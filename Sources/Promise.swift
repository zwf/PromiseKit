import Dispatch

/**
 A *promise* represents the future value of a (usually) asynchronous task.

 To obtain the value of a promise we call `then`.

 Promises are chainable: `then` returns a promise, you can call `then` on
 that promise, which returns a promise, you can call `then` on that
 promise, et cetera.

 Promises start in a pending state and *resolve* with a value to become
 *fulfilled* or an `Error` to become rejected.

 - SeeAlso: [PromiseKit 101](http://promisekit.org/docs/)
 */
public final class Promise<T>: Thenable, Catchable, Mixin {

    @inline(__always)
    convenience init(_: PendingIntializer) {
        self.init(schrödinger: .pending(Handlers()))
    }

    @inline(__always)
    init(schrödinger cat: Schrödinger<Result<T>>) {
        barrier = DispatchQueue(label: "org.promisekit.barrier", attributes: .concurrent)
        _schrödinger = cat
    }

    /**
      - Remark: This initializer requires the `.start` parameter because otherwise Swift
        will in various circumstances instead create a new `Promise<T -> Void>` via the
        other initializer rather than do this…
    */
    public convenience init(seal body: (Sealant<T>) throws -> Void) {
        do {
            self.init(.pending)
            let sealant = Sealant{ self.schrödinger = .resolved($0) }
            try body(sealant)
        } catch {
            _schrödinger = .resolved(.rejected(error))
        }
    }

#if swift(>=4.0)  // causes ambiguity in Swift 3
    public convenience init(assimilate body: () throws -> Promise) {
        self.init { try body().pipe(to: $0.resolve) }
    }
#endif

    /// - TODO: Ideally this would not exist, since it is better to make a `Guarantee`.
    /// - Remark: It is possible to create a `Promise<Error>` with this method. Generally this isn’t what you really want and trying to use it will quickly reveal that and then you'll realize your mistake.
    /// - Note: `Promise()` creates a *fulfilled* `Void` promise.
    public convenience init(value: T) {
        self.init(schrödinger: .resolved(.fulfilled(value)))
    }

    public convenience init(error: Error) {
        self.init(schrödinger: .resolved(.rejected(error)))
    }

    //TODO optimization: don't need these if instantiated sealed
    let barrier: DispatchQueue
    var _schrödinger: Schrödinger<Result<T>>

    public var result: Result<T>? {
        switch schrödinger {
        case .pending:
            return nil
        case .resolved(let result):
            return result
        }
    }

    public static func pending() -> (promise: Promise, seal: Sealant<T>) {
        let promise = Promise(.pending)
        let sealant = Sealant{ promise.schrödinger = .resolved($0) }
        return (promise, sealant)
    }
}

public extension Promise where T == Void {
    convenience init() {
        self.init(value: ())
    }
}
