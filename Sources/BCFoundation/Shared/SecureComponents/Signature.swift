import Foundation
import CryptoKit
import URKit

/// A cryptographic signature created by EdDSA over Curve25519.
///
/// https://datatracker.ietf.org/doc/html/rfc8032
public struct Signature: Equatable {
    public let rawValue: Data
    
    public init?(rawValue: Data) {
        guard rawValue.count == 64 else {
            return nil
        }
        self.rawValue = rawValue
    }
    
    public var description: String {
        "Signature(\(rawValue.hex))"
    }
}

extension Signature {
    public var cbor: CBOR {
        let type = CBOR.unsignedInt(1)
        let sig = CBOR.data(self.rawValue)
        
        return CBOR.array([type, sig])
    }
    
    public var taggedCBOR: CBOR {
        CBOR.tagged(.signature, cbor)
    }
    
    public init(cbor: CBOR) throws {
        guard case let CBOR.array(elements) = cbor else {
            throw CBORError.invalidFormat
        }
        
        guard elements.count == 2 else {
            throw CBORError.invalidFormat
        }
        
        guard
            case let CBOR.unsignedInt(type) = elements[0],
            type == 1
        else {
            throw CBORError.invalidFormat
        }

        guard
            case let CBOR.data(sigData) = elements[1],
            let sig = Signature(rawValue: sigData)
        else {
            throw CBORError.invalidFormat
        }
        
        self = sig
    }
    
    public init(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(.signature, cbor) = taggedCBOR else {
            throw CBORError.invalidTag
        }
        try self.init(cbor: cbor)
    }
    
    public init(taggedCBOR: Data) throws {
        try self.init(taggedCBOR: CBOR(taggedCBOR))
    }
}
