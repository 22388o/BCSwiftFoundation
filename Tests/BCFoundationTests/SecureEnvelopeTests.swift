import XCTest
import BCFoundation
import WolfBase

class SecureEnvelopeTests: XCTestCase {
    static let plaintext = "Some mysteries aren't meant to be solved.".utf8Data

    static let aliceSeed = Seed(data: "82f32c855d3d542256180810797e0073".hexData!)!
    static let aliceIdentity = SecureIdentity(aliceSeed, salt: "Salt")
    static let alicePeer = SecurePeer(identity: aliceIdentity)
    
    static let bobSeed = Seed(data: "187a5973c64d359c836eba466a44db7b".hexData!)!
    static let bobIdentity = SecureIdentity(bobSeed, salt: "Salt")
    static let bobPeer = SecurePeer(identity: bobIdentity)
    
    static let carolSeed = Seed(data: "8574afab18e229651c1be8f76ffee523".hexData!)!
    static let carolIdentity = SecureIdentity(carolSeed, salt: "Salt")
    static let carolPeer = SecurePeer(identity: carolIdentity)

    func testPlaintext() {
        // Alice sends a plaintext message to Bob
        let envelope = SecureEnvelope(plaintext: Self.plaintext)
        
        // Bob reads the message.
        XCTAssertEqual(envelope.plaintext, Self.plaintext)
    }
    
    func testSignedPlaintext() {
        // Alice sends a signed plaintext message to Bob.
        let envelope = SecureEnvelope(plaintext: Self.plaintext, signer: Self.aliceIdentity)
        
        // Bob receives the message and verifies that it was signed by Alice
        XCTAssertTrue(envelope.hasValidSignature(from: Self.alicePeer))
        // Confirm that it wasn't signed by Carol
        XCTAssertFalse(envelope.hasValidSignature(from: Self.carolPeer))

        // Bob reads the message.
        XCTAssertEqual(envelope.plaintext, Self.plaintext)
    }
    
    func testMultisignedPlaintext() {
        // Alice and Carol jointly send a signed plaintext message to Bob.
        let envelope = SecureEnvelope(plaintext: Self.plaintext, signers: [Self.aliceIdentity, Self.carolIdentity])
        
        // Bob receives the message and verifies that it was signed by both Alice and Carol
        XCTAssertTrue(envelope.hasValidSignatures(from: [Self.alicePeer, Self.carolPeer]))

        // Bob reads the message.
        XCTAssertEqual(envelope.plaintext, Self.plaintext)
    }
    
    func testThresholdMultisignedPlaintext() {
        // Alice sends a signed plaintext message to Bob.
        let envelope = SecureEnvelope(plaintext: Self.plaintext, signer: Self.aliceIdentity)

        // Bob receives the message and verifies that it was signed by either Alice or Carol
        XCTAssertTrue(envelope.hasValidSignatures(from: [Self.alicePeer, Self.carolPeer], threshold: 1))
        // Checking for both signatures fails.
        XCTAssertFalse(envelope.hasValidSignatures(from: [Self.alicePeer, Self.carolPeer], threshold: 2))

        // Bob reads the message.
        XCTAssertEqual(envelope.plaintext, Self.plaintext)
    }
    
    func testSymmetricEncryption() {
        // Alice and Bob have agreed to use this key.
        let key = SecureMessage.Key()

        // Alice sends a message encrypted with a symmetric key to Bob.
        let envelope = SecureEnvelope(plaintext: Self.plaintext, key: key)

        // Bob decrypts and reads the message
        XCTAssertEqual(envelope.plaintext(with: key), Self.plaintext)

        // Can't read with no key
        XCTAssertNil(envelope.plaintext)
        
        // Can't read with incorrect key
        XCTAssertNil(envelope.plaintext(with: SecureMessage.Key()))
    }
    
    func testSignThenEncrypt() {
        // Alice and Bob have agreed to use this key.
        let key = SecureMessage.Key()

        // Alice signs a plaintext message, then encrypts it.
        let innerSignedEnvelope = SecureEnvelope(plaintext: Self.plaintext, signer: Self.aliceIdentity)
        let envelope = SecureEnvelope(inner: innerSignedEnvelope, key: key)
        
        // Bob decrypts the outer envelope using the shared key.
        guard
            let innerEnvelope = envelope.inner(with: key)
        else {
            XCTFail()
            return
        }
        // Bob validates Alice's signature
        XCTAssertTrue(innerEnvelope.hasValidSignature(from: Self.alicePeer))
        // Bob reads the message.
        XCTAssertEqual(innerEnvelope.plaintext, Self.plaintext)
    }
    
    func testEncryptThenSign() {
        // Alice and Bob have agreed to use this key.
        let key = SecureMessage.Key()
        
        // Alice encrypts a message, then signs it.
        let innerEncryptedEnvelope = SecureEnvelope(plaintext: Self.plaintext, key: key)
        let envelope = SecureEnvelope(inner: innerEncryptedEnvelope, signer: Self.aliceIdentity)
        
        // Bob checks the signature of the outer envelope, then decrypts the inner envelope.
        guard
            envelope.hasValidSignature(from: Self.alicePeer),
            let innerEnvelope = envelope.inner,
            let plaintext = innerEnvelope.plaintext(with: key)
        else {
            XCTFail()
            return
        }
        
        // Bob reads the message.
        XCTAssertEqual(plaintext, Self.plaintext)
    }
}
