@inline(__always)
public func race<U: Thenable>(_ thenables: U...) -> Promise<U.T> {
    return race(thenables)
}

/// - Remark: returns Promise(error: PMKError.badInput) if array is empty
public func race<U: Thenable>(_ thenables: [U]) -> Promise<U.T> {
    guard !thenables.isEmpty else {
        return Promise(error: PMKError.badInput)
    }
    let result = Promise<U.T>(.pending)
    for thenable in thenables {
        thenable.pipe{ result.schrödinger = .resolved($0) }
    }
    return result
}

/// - Remark: there is no array version of this as we would have to fatalError in the case of an empty array, use the promise version
@inline(__always)
public func race<T>(_ guarantees: Guarantee<T>...) -> Guarantee<T> {
    let (result, seal) = Guarantee<T>.pending()
    for thenable in guarantees {
        thenable.pipe(to: seal)
    }
    return result
}
