import Foundation
import CryptoSwift
import URKit
import CryptoKit
import protocol WolfBase.DataProvider

/// A secure encrypted message.
///
/// Implemented using the IETF ChaCha20-Poly1305 encryption.
///
/// https://datatracker.ietf.org/doc/html/rfc8439
///
/// To facilitate decoding, it is recommended that the plaintext of a `Message` be
/// tagged CBOR.
public struct Message: CustomStringConvertible, Equatable {
    public let ciphertext: Data
    public let aad: Data // Additional authenticated data (AAD) per RFC8439
    public let nonce: Nonce
    public let auth: Auth
    
    public init?(ciphertext: Data, aad: Data, nonce: Nonce, auth: Auth) {
        self.ciphertext = ciphertext
        self.aad = aad
        self.nonce = nonce
        self.auth = auth
    }
    
    public var description: String {
        "Message(ciphertext: \(ciphertext.hex), aad: \(aad.hex), nonce: \(nonce), auth: \(auth))"
    }
    
    public struct Nonce: CustomStringConvertible, Equatable, Hashable, RawRepresentable {
        public let rawValue: Data
        
        public init?(rawValue: Data) {
            guard rawValue.count == 12 else {
                return nil
            }
            self.rawValue = rawValue
        }
        
        public init() {
            self.init(rawValue: SecureRandomNumberGenerator.shared.data(count: 12))!
        }

        public var bytes: [UInt8] {
            rawValue.bytes
        }
        
        public var description: String {
            rawValue.hex.flanked("Nonce(", ")")
        }
    }
    
    public struct Auth: CustomStringConvertible, Equatable, Hashable, RawRepresentable {
        public let rawValue: Data
        
        public init?(rawValue: Data) {
            guard rawValue.count == 16 else {
                return nil
            }
            self.rawValue = rawValue
        }
        
        public init?(_ bytes: [UInt8]) {
            self.init(rawValue: Data(bytes))
        }
        
        public var bytes: [UInt8] {
            rawValue.bytes
        }
        
        public var description: String {
            rawValue.hex.flanked("auth(", ")")
        }
    }
}

extension Message {
    public static func sharedKey(identityPrivateKey: PrivateAgreementKey, peerPublicKey: PublicAgreementKey) -> SymmetricKey {
        let sharedSecret = try! identityPrivateKey.cryptoKitForm.sharedSecretFromKeyAgreement(with: peerPublicKey.cryptoKitForm)
        return SymmetricKey(rawValue: sharedSecret.hkdfDerivedSymmetricKey(using: SHA512.self, salt: Data(), sharedInfo: "agreement".utf8Data, outputByteCount: 32).withUnsafeBytes { Data($0) })!
    }
}

extension Message {
    public var cbor: CBOR {
        let type = CBOR.unsignedInt(1)
        let ciphertext = CBOR.data(self.ciphertext)
        let aad = CBOR.data(self.aad)
        let nonce = CBOR.data(self.nonce.rawValue)
        let auth = CBOR.data(self.auth.rawValue)

        return CBOR.array([type, ciphertext, aad, nonce, auth])
    }
    
    public var taggedCBOR: CBOR {
        CBOR.tagged(URType.message.tag, cbor)
    }
    
    public init(cbor: CBOR) throws {
        let (ciphertext, aad, nonce, auth) = try Self.decode(cbor: cbor)
        self.init(ciphertext: ciphertext, aad: aad, nonce: nonce, auth: auth)!
    }
    
    public init(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(URType.message.tag, cbor) = taggedCBOR else {
            throw CBORError.invalidTag
        }
        try self.init(cbor: cbor)
    }
    
    public init?(taggedCBOR: Data) {
        try? self.init(taggedCBOR: CBOR(taggedCBOR))
    }

    public static func decode(cbor: CBOR) throws -> (ciphertext: Data, aad: Data, nonce: Nonce, auth: Auth)
    {
        guard
            case let CBOR.array(elements) = cbor,
            elements.count == 5,
            case let CBOR.unsignedInt(type) = elements[0],
            type == 1,
            case let CBOR.data(ciphertext) = elements[1],
            case let CBOR.data(aad) = elements[2],
            case let CBOR.data(nonceData) = elements[3],
            let nonce = Nonce(rawValue: nonceData),
            case let CBOR.data(authData) = elements[4],
            let auth = Auth(rawValue: authData)
        else {
            throw CBORError.invalidFormat
        }
        
        return (ciphertext, aad, nonce, auth)
    }
    
    public static func decode(taggedCBOR: CBOR) throws -> (ciphertext: Data, aad: Data, nonce: Nonce, auth: Auth) {
        guard case let CBOR.tagged(URType.message.tag, cbor) = taggedCBOR else {
            throw CBORError.invalidTag
        }
        return try decode(cbor: cbor)
    }
}

extension Message {
    public var ur: UR {
        return try! UR(type: URType.message.type, cbor: cbor)
    }
    
    public init(ur: UR) throws {
        guard ur.type == URType.message.type else {
            throw URError.unexpectedType
        }
        let cbor = try CBOR(ur.cbor)
        try self.init(cbor: cbor)
    }
    
    public static func decode(ur: UR) throws -> (ciphertext: Data, aad: Data, nonce: Nonce, auth: Auth) {
        guard ur.type == URType.message.type else {
            throw URError.unexpectedType
        }
        let cbor = try CBOR(ur.cbor)
        return try Self.decode(cbor: cbor)
    }
}
