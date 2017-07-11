
// Caveats (specify fixes alongside)
// * Promise { throw E.dummy } is interpreted as `Promise<() throws -> Void>` of all things
// * Promise(E.dummy) is interpreted as `Promise<E>`


// Remarks:
// * We typically use `.pending()` to reduce nested insanities in your backtraces

enum Schrödinger<R> {
    case pending(Handlers<R>)
    case resolved(R)
}

public enum Result<T> {
    case rejected(Error)
    case fulfilled(T)

    public var value: T? {
        switch self {
        case .fulfilled(let value):
            return value
        case .rejected:
            return nil
        }
    }
}

class Handlers<R> {
    var bodies: [(R) -> Void] = []
}

public enum UnambiguousInitializer {
    case start
}

/**
 Not private or conformance to `Thenable` outside this module has a link error.
 Sadly this cascades and makes a lot of other stuff in here `internal` also :(
 */
protocol Mixin: class {
    associatedtype R
    var barrier: DispatchQueue { get }
    var _schrödinger: Schrödinger<R> { get set }
    var schrödinger: Schrödinger<R> { get set }
}

extension Mixin {
    var schrödinger: Schrödinger<R> {
        get {
            var result: Schrödinger<R>!
            barrier.sync {
                result = _schrödinger
            }
            return result
        }
        set {
            guard case .resolved(let result) = newValue else {
                fatalError()
            }
            var bodies: [(R) -> Void]!
            barrier.sync(flags: .barrier) {
                guard case .pending(let handlers) = self._schrödinger else {
                    return  // already fulfilled!
                }
                bodies = handlers.bodies
                self._schrödinger = newValue
            }

            //FIXME we are resolved so should `pipe(to:)` be called at this instant, “thens are called in order” would be invalid
            //NOTE we don’t do this in the above `sync` because that could potentially deadlock
            //THOUGH since `then` etc. typically invoke after a run-loop cycle, this issue is somewhat less severe

            if let bodies = bodies {
                for body in bodies {
                    body(result)
                }
            }
        }
    }
    public func pipe(to body: @escaping (R) -> Void) {
        var result: R?
        barrier.sync {
            switch _schrödinger {
            case .pending:
                break
            case .resolved(let resolute):
                result = resolute
            }
        }
        if result == nil {
            barrier.sync(flags: .barrier) {
                switch _schrödinger {
                case .pending(let handlers):
                    handlers.bodies.append(body)
                case .resolved(let resolute):
                    result = resolute
                }
            }
        }
        if let result = result {
            body(result)
        }
    }
}

enum PendingIntializer {
    case pending
}



/// Makes `on` usage more elegant
public typealias QoS = DispatchQoS


/// used to namespace identical functions in extensions
public enum PMKNamespacer {
    case promise
}


//TODO make it possible to disable this *and* make it possible to change the output location *and* make the default stderr or if available, NSLog
let pmkWarn: (String) -> Void = { print($0) }
