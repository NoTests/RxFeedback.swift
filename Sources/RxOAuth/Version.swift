import class Foundation.NSObject

public struct Version<Value>: Equatable {
    fileprivate let mutation: NSObject
    public let value: Value

    public init(_ value: Value) {
        self.mutation = NSObject()
        self.value = value
    }
}

extension Version {
    public static func == (lhs: Version<Value>, rhs: Version<Value>) -> Bool {
        return lhs.mutation == rhs.mutation
    }
}
