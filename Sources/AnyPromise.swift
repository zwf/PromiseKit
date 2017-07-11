

@objc(AnyPromise)
public final class AnyPromise: NSObject, Thenable, Catchable, Mixin {
    public var result: Result<Any?>? {
        switch schrödinger {
        case .resolved(let value):
            return unwrap(value)
        case .pending:
            return nil
        }
    }

    let barrier = DispatchQueue(label: "org.promisekit.barrier", attributes: .concurrent)
    var _schrödinger: Schrödinger<Any?>

    public func pipe(to body: @escaping (Result<Any?>) -> Void) {
        let body = { body(unwrap($0)) }
        pipe(to: body)
    }

    public override init() {
        _schrödinger = .resolved(nil)
        super.init()
    }

    private init(schrödinger: Schrödinger<Any?>) {
        _schrödinger = schrödinger
    }

    @objc static func promiseWithValue(_ value: Any?) -> AnyPromise {
        return AnyPromise(schrödinger: .resolved(value))
    }

    @objc static func promiseWithResolverBlock(_ body: @convention(block) (@escaping (Any?) -> Void) -> Void) -> AnyPromise {
        let promise = AnyPromise(schrödinger: .pending(Handlers()))
        body{ promise.schrödinger = .resolved($0) }
        return promise
    }

    @objc func pipeTo(_ body: @convention(block) @escaping (Any?) -> Void) {
        pipe(to: body)
    }

    @objc var value: Any? {
        switch schrödinger {
        case .resolved(let obj):
            return obj
        case .pending:
            return nil
        }
    }

    @objc var pending: Bool { return isPending }
    @objc var fulfilled: Bool { return isFulfilled }
    @objc var rejected: Bool { return isRejected }
    @objc var resolved: Bool { return isResolved }
}


private func unwrap(_ any: Any?) -> Result<Any?> {
    if let error = any as? Error {
        return .rejected(error)
    } else {
        return .fulfilled(any)
    }
}
