import Dispatch

public protocol Catchable: Thenable
{}

extension Catchable {
    public func ensure(on: ExecutionContext? = NextMainRunloopContext(), that body: @escaping () -> Void) -> Self {
        pipe { _ in
            go(on, body)
        }
        return self
    }

    @discardableResult
    public func `catch`(on: ExecutionContext = NextMainRunloopContext(), policy: CatchPolicy = .allErrorsExceptCancellation, handler body: @escaping (Error) -> Void) -> ChainFinalizer {
        let finally = ChainFinalizer()
        pipe { result in
            switch result {
            case .fulfilled:
                finally.schrödinger = .resolved(())
            case .rejected(let error):
                if policy == .allErrorsExceptCancellation, error.isCancelled {
                    pmkWarn("PromiseKit: warning: a catch handler did not execute because the error was deemend a cancellation error")
                    return
                }
                on.pmkAsync {
                    body(error)
                    // must occur after `catch`
                    // generally we don't have such guards in this file because
                    // a promise must resolve before the next such block runs,
                    // but here the two schrodingers are both tied to the same
                    // previous state and if they run on different queues they
                    // will likely run simultaneously: not exactly “finally”
                    finally.schrödinger = .resolved(())
                }
            }
        }
        return finally
    }

    public var error: Error? {
        switch result {
        case .rejected(let error)?:
            return error
        case .fulfilled?, nil:
            return nil
        }
    }

    public func recover(on: ExecutionContext = NextMainRunloopContext(), transform body: @escaping (Error) throws -> T) -> Promise<T> {
        let promise = Promise<T>(.pending)
        pipe { result in
            switch result {
            case .rejected(let error):
                on.pmkAsync {
                    do {
                        promise.schrödinger = .resolved(.fulfilled(try body(error)))
                    } catch {
                        promise.schrödinger = .resolved(.rejected(error))
                    }
                }
            case .fulfilled:
                promise.schrödinger = .resolved(result)
            }
        }
        return promise
    }

    /// - Remark: Complete recovery (no errors can propogate), thus returns `Guarantee`
    public func recover(on: ExecutionContext = NextMainRunloopContext(), transform body: @escaping (Error) -> T) -> Guarantee<T> {
        let (guarantee, seal) = Guarantee<T>.pending()
        pipe { result in
            switch result {
            case .rejected(let error):
                on.pmkAsync {
                    seal(body(error))
                }
            case .fulfilled(let value):
                seal(value)
            }
        }
        return guarantee
    }

    /// - Remark: Complete recovery (no errors can propogate), thus returns `Guarantee`
    public func recover(on: ExecutionContext = NextMainRunloopContext(), transform body: @escaping (Error) -> Guarantee<T>) -> Guarantee<T> {
        let (guarantee, seal) = Guarantee<T>.pending()
        pipe { result in
            switch result {
            case .rejected(let error):
                on.pmkAsync {
                    body(error).pipe(to: seal)
                }
            case .fulfilled(let value):
                seal(value)
            }
        }
        return guarantee
    }

    /**
      - Remark: Swift infers the other form for one-liners:

          foo().recover{ Promise() }  // => Promise<Promise<Void>>

        We don’t know how to stop it.
     */
    public func recover<U: Thenable>(on: ExecutionContext = NextMainRunloopContext(), transform body: @escaping (Error) throws -> U) -> Promise<T> where U.T == T {
        let promise = Promise<T>(.pending)
        pipe { result in
            switch result {
            case .rejected(let error):
                on.pmkAsync {
                    do {
                        let intermediary = try body(error)
                        guard intermediary !== promise else { throw PMKError.returnedSelf }
                        intermediary.pipe{ promise.schrödinger = .resolved($0) }
                    } catch {
                        promise.schrödinger = .resolved(.rejected(error))
                    }
                }
            case .fulfilled:
                promise.schrödinger = .resolved(result)
            }
        }
        return promise
    }

    /**
      Terminate this chain and print any error.and

      Provided when you have error handling in place in other branches of the chain and do not need or want error handling here.and

      Named to imply this is a drastic action.
     */
    public func cauterize() {
        `catch` { error in
            print("PromiseKit: unhandled error:", error)
        }
    }
}


public final class ChainFinalizer {  //TODO thread-safety!
    fileprivate var schrödinger: Schrödinger<Void> = .pending(Handlers()) {
        didSet {
            guard case .pending(let handlers) = oldValue else { fatalError() }
            for handler in handlers.bodies {
                handler(())
            }
        }
    }

    @discardableResult
    public func finally(on: ExecutionContext? = NextMainRunloopContext(), _ body: @escaping () -> Void) -> ChainFinalizer {
        func doit() { go(on, body) }
        switch schrödinger {
        case .pending(let handlers):
            handlers.bodies.append(doit)
        case .resolved:
            doit()
        }
        return self
    }
}
