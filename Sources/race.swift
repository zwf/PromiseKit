@inline(__always)
public func race<U: Thenable>(_ thenables: U...) -> Promise<U.T> {
    return race(thenables)
}

public func race<U: Thenable>(_ thenables: [U]) -> Promise<U.T> {
    let result = Promise<U.T>(.pending)
    for thenable in thenables {
        thenable.pipe{ result.schrödinger = .resolved($0) }
    }
    return result
}

@inline(__always)
public func race<T>(_ guarantees: Guarantee<T>...) -> Guarantee<T> {
    return race(guarantees)
}

public func race<T>(_ guarantees: [Guarantee<T>]) -> Guarantee<T> {
    let (result, seal) = Guarantee<T>.pending()
    for thenable in guarantees {
        thenable.pipe(to: seal)
    }
    return result
}

