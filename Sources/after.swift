import struct Foundation.TimeInterval
import Dispatch

/**
     after(.seconds(2)).then {
         //…
     }

 - Returns: A `Guarantee` that resolves after the specified duration.
*/
public func after(_ interval: DispatchTimeInterval) -> Guarantee<Void> {
    let (guarantee, seal) = Guarantee<Void>.pending()
  #if swift(>=4.0)
    DispatchQueue.global().asyncAfter(deadline: .now() + interval) { seal(()) }
  #else
    DispatchQueue.global().asyncAfter(deadline: .now() + interval, execute: seal)
  #endif
    return guarantee
}
