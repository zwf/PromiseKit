/**
 Judicious use of `firstly` *may* make chains more readable.

 Compare:

     URLSession.shared.dataTask(url: url1).then {
         URLSession.shared.dataTask(url: url2)
     }.then {
         URLSession.shared.dataTask(url: url3)
     }

 With:

     firstly {
         URLSession.shared.dataTask(url: url1)
     }.then {
         URLSession.shared.dataTask(url: url2)
     }.then {
         URLSession.shared.dataTask(url: url3)
     }
 */
public func firstly<U: Thenable>(execute body: () throws -> U) -> Promise<U.T> {
    do {
        let (promise, seal) = Promise<U.T>.pending()
        try body().pipe(to: seal.resolve)
        return promise
    } catch {
        return Promise(error: error)
    }
}

/**
 Useful for starting chains without promises:

     let promise: Promise<Void>
     do {
         promise = Promise(try foo())
     } catch {
         promise = Promise(error: error)
     }
     promise.then {
         //…
     }

 With:

     firstly {
         try foo()
     }.then {
         //…
     }
 */
public func firstly<T>(execute body: () throws -> T) -> Promise<T> {
    do {
        return Promise(try body())
    } catch {
        return Promise(error: error)
    }
}
