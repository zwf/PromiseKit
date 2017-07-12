import Dispatch

public func when<U, V>(fulfilled u: Promise<U>, _ v: Promise<V>) -> Promise<(U, V)> {
    return when(fulfilled: [u.asVoid(), v.asVoid()]).then{ _ in (u.value!, v.value!) }
}

public func when<U, V, X>(fulfilled u: Promise<U>, _ v: Promise<V>, _ x: Promise<X>) -> Promise<(U, V, X)> {
    return when(fulfilled: [u.asVoid(), v.asVoid(), x.asVoid()]).then{ _ in (u.value!, v.value!, x.value!) }
}

public func when<U, V, X, Y>(fulfilled u: Promise<U>, _ v: Promise<V>, _ x: Promise<X>, _ y: Promise<Y>) -> Promise<(U, V, X, Y)> {
    return when(fulfilled: [u.asVoid(), v.asVoid(), x.asVoid(), y.asVoid()]).then{ _ in (u.value!, v.value!, x.value!, y.value!) }
}

public func when<U, V, X, Y, Z>(fulfilled u: Promise<U>, _ v: Promise<V>, _ x: Promise<X>, _ y: Promise<Y>, _ z: Promise<Z>) -> Promise<(U, V, X, Y, Z)> {
    return when(fulfilled: [u.asVoid(), v.asVoid(), x.asVoid(), y.asVoid(), z.asVoid()]).then{ _ in (u.value!, v.value!, x.value!, y.value!, z.value!) }
}

/// - Remark: There is no `...` variant, because it is then confusing that you put a splat in and don't get a splat out, when compared with the typical usage for our above splatted kinds
public func when<U: Thenable>(fulfilled thenables: [U]) -> Promise<[U.T]> {

    guard !thenables.isEmpty else {
        return Promise(value: [])
    }

    let barrier = DispatchQueue(label: "org.promisekit.when")
    let rv = Promise<[U.T]>(.pending)
    var values = Array<U.T!>(repeating: nil, count: thenables.count)
    var x = thenables.count

    for (index, thenable) in thenables.enumerated() {
        thenable.pipe { result in
            switch result {
            case .rejected(let error):
                rv.schrödinger = .resolved(.rejected(error))
            case .fulfilled(let value):
                var done = false
                barrier.sync(flags: .barrier) {
                    values[index] = value
                    x -= 1
                    done = x == 0
                }
                if done {
                    rv.schrödinger = .resolved(.fulfilled(values))
                }
            }
        }
    }

    return rv
}

public func when<U: Thenable>(resolved thenables: [U]) -> Guarantee<[Result<U.T>]> {
    let barrier = DispatchQueue(label: "org.promisekit.when")
    let (rv, seal) = Guarantee<[Result<U.T>]>.pending()
    var results = Array<Result<U.T>!>(repeating: nil, count: thenables.count)
    var x = thenables.count

    for (index, thenable) in thenables.enumerated() {
        thenable.pipe { result in
            var done = false
            barrier.sync(flags: .barrier) {
                results[index] = result
                x -= 1
                done = x == 0
            }
            if done {
                seal(results)
            }
        }
    }

    return rv

}

@discardableResult
public func when<U>(fulfilled guarantees: [Guarantee<U>]) -> Guarantee<[U]> {
    let (rv, seal) = Guarantee<[U]>.pending()
    var values = Array<U!>(repeating: nil, count: guarantees.count)
    var x = guarantees.count

    for (index, guarantee) in guarantees.enumerated() {
        guarantee.pipe { (value: U) in
            values[index] = value
            x -= 1
            if x == 0 {
                seal(values)
            }
        }
    }

    return rv
}

public func when<T, A: Thenable, B: Thenable>(resolved a: A, _ b: B) -> Guarantee<[Result<A.T>]> where A.T == T, B.T == T {
    let (rv, seal) = Guarantee<[Result<T>]>.pending()
    var results = [Result<T>!](repeating: nil, count: 2)
    var x = 2

    func thereyet() {
        x -= 1  //FIXME thread-safety!
        if x == 0 {
            seal(results)
        }
    }

    a.pipe {
        results[0] = $0
        thereyet()
    }
    b.pipe {
        results[1] = $0
        thereyet()
    }
    return rv
}
