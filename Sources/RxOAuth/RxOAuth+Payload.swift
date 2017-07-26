import RxSwift

public enum OAuthError: Error {
    case tokenInvalidated
}

public protocol OAuthResponseRepresentable {
    associatedtype PayloadType

    var response: OAuthResponse<PayloadType> {
        get
    }
}

extension OAuthResponse: OAuthResponseRepresentable {
    public var response: OAuthResponse<Payload> {
        return self
    }
}

extension OAuthResponse {
    public func payload() throws -> Payload {
        switch self {
        case .success(let payload):
            return payload
        case .tokenInvalidated:
            throw OAuthError.tokenInvalidated
        }
    }
}

extension PrimitiveSequenceType where ElementType: OAuthResponseRepresentable {
    public func payload() -> PrimitiveSequence<TraitType, ElementType.PayloadType> {
        return self.primitiveSequence.map { try $0.response.payload() }
    }
}
