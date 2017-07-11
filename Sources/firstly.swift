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

 - Note: There is only a Promise version of this because otherwise this:

       firstly {
           print("hi")
           return Promise(value: 3)
       }.then {
           XCTAssertEqual($0, 3)
       }

   Genreates this error:

       Cannot convert return expression of type Promise<Int> to return type Guarantee<Int>

   This is the case for pretty much any options we provide :(
 */
public func firstly<T>(execute body: () throws -> Promise<T>) -> Promise<T> {
    do {
        return try body()
    } catch {
        return Promise(error: error)
    }
}

