import Foundation
import CryptoSwift
@_exported import URKit

public struct SeedDigest {
    public let digest: Data
    
    public var cbor: CBOR {
        CBOR.data(digest)
    }
    
    public var taggedCBOR: CBOR {
        CBOR.tagged(.seedDigest, cbor)
    }
    
    public init(digest: Data) throws {
        guard digest.count == SHA2.Variant.sha256.digestLength else {
            throw CBORError.invalidFormat
        }
        self.digest = digest
    }
    
    public init(cbor: CBOR) throws {
        guard case let CBOR.data(bytes) = cbor else {
            throw CBORError.invalidFormat
        }
        try self.init(digest: bytes.data)
    }
    
    public init?(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(.seedDigest, cbor) = taggedCBOR else {
            return nil
        }
        try self.init(cbor: cbor)
    }
}
