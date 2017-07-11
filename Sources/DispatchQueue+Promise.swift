import Dispatch

extension DispatchQueue {
    public func promise<T>(group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], execute body: @escaping () throws -> T) -> Promise<T> {
        let promise = Promise<T>(.pending)
        async(group: group, qos: qos, flags: flags) {
            do {
                promise.schrödinger = .resolved(.fulfilled(try body()))
            } catch {
                promise.schrödinger = .resolved(.rejected(error))
            }
        }
        return promise
    }

    public func promise<T>(group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], execute body: @escaping () -> T) -> Guarantee<T> {
        let (promise, seal) = Guarantee<T>.pending()
        async(group: group, qos: qos, flags: flags) {
            seal(body())
        }
        return promise
    }
}
