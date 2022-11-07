
import XCTest
@testable import AriesFramework

class OobTest: XCTestCase {

    var faberAgent: Agent!
    var aliceAgent: Agent!
    let makeConnectionConfig = CreateOutOfBandInvitationConfig(
        label: "Faber College",
        goalCode: "p2p-messaging",
        goal: "To make a connection")
    let receiveInvitationConfig = ReceiveOutOfBandInvitationConfig(
        autoAcceptConnection: false)
    let credentialPreview = CredentialPreview.fromDictionary(["name": "Alice", "age": "20"])
    var credentialTemplate: CreateOfferOptions!

    override func setUp() async throws {
        try await super.setUp()

        let faberConfig = try TestHelper.getBaseConfig(name: "faber")
        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faberAgent.initialize()

        let aliceConfig = try TestHelper.getBaseConfig(name: "alice")
        aliceAgent = Agent(agentConfig: aliceConfig, agentDelegate: nil)
        try await aliceAgent.initialize()

        let credDefId = try await prepareForIssuance(faberAgent, ["name", "age"])
        credentialTemplate = CreateOfferOptions(
            credentialDefinitionId: credDefId,
            credentialValues: credentialPreview.attributes,
            autoAcceptCredential: .never)
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try await faberAgent.reset()
        try await aliceAgent.reset()
    }

    func testCreateOutOfBandInvitation() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)

        XCTAssertEqual(outOfBandRecord.autoAcceptConnection, true)
        XCTAssertEqual(outOfBandRecord.role, .Sender)
        XCTAssertEqual(outOfBandRecord.state, .AwaitResponse)
        XCTAssertEqual(outOfBandRecord.reusable, false)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.goal, makeConnectionConfig.goal)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.goalCode, makeConnectionConfig.goalCode)
        XCTAssertEqual(outOfBandRecord.outOfBandInvitation.label, makeConnectionConfig.label)
    }

    func testCreateWithHandshakeAndRequests() async throws {
        let message = TrustPingMessage(comment: "Hello")
        let config = CreateOutOfBandInvitationConfig(
            label: "test-connection",
            handshakeProtocols: [HandshakeProtocol.Connections],
            messages: [message])
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: config)
        let invitation = outOfBandRecord.outOfBandInvitation

        XCTAssertTrue(invitation.handshakeProtocols!.contains(.Connections))
        XCTAssertEqual(try invitation.getRequests().count, 1)
    }

    func testCreateWithRequest() async throws {
        let (message, _) = try await faberAgent.credentialService.createOffer(options: credentialTemplate)
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(handshake: false, messages: [message]))
        let invitation = outOfBandRecord.outOfBandInvitation

        XCTAssertNotNil(invitation.handshakeProtocols)
        XCTAssertEqual(invitation.getRequests().count, 1)

        if let service = invitation.services[0] as OutOfBandDidDocumentService {
            XCTAssertEqual(service.serviceEndpoint, DID_COMM_TRANSPORT_QUEUE)
            XCTAssertTrue(service.recipientKeys[0].starts(with: "did:key"))
        } else {
            XCTFail("Service is not OutOfBandDidDocumentService")
        }
    }

    func testReceiveInvitation() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)
        let invitation = outOfBandRecord.outOfBandInvitation

        let (receivedOutOfBandRecord, connectionRecord) = try await aliceAgent.oob.receiveInvitation(invitation)

        XCTAssertEqual(receivedOutOfBandRecord.role, .Receiver)
        XCTAssertEqual(receivedOutOfBandRecord.state, .Initial)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.goal, makeConnectionConfig.goal)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.goalCode, makeConnectionConfig.goalCode)
        XCTAssertEqual(receivedOutOfBandRecord.outOfBandInvitation.label, makeConnectionConfig.label)
    }

    func testConnectionWithURL() async throws {
        let outOfBandRecord = try await faberAgent.oob.createInvitation(config: makeConnectionConfig)
        let invitation = outOfBandRecord.outOfBandInvitation
        let url = outOfBandInvitation.toUrl(domain: "http://example.com")

        let (_, aliceFaberConnection) = try await aliceAgent.oob.receiveInvitationFromUrl(url)
        XCTAssertEqual(aliceFaberConnection.state, .Complete)

        let faberAliceConnection = try await faberAgent.connectionService.findByInvitationKey(try invitation.invitationKey())
        XCTAssertEqual(faberAliceConnection?.state, .Complete)

        XCTAssertEqual(faberAliceConnection?.alias, makeConnectionConfig.alias)
        XCTAssertEqual(try? TestHelper.isConnectedWith(received: faberAliceConnection, connection: aliceFaberConnection), true)
        XCTAssertEqual(try? TestHelper.isConnectedWith(received: aliceFaberConnection, connection: faberAliceConnection), true)
    }

    func testCredentialOffer() async throws {
        let (message, _) = try await faberAgent.credentialService.createOffer(options: credentialTemplate)
        let outOfBandRecord = try await faberAgent.oob.createInvitation(
            config: CreateOutOfBandInvitationConfig(messages: [message]))
        let invitation = outOfBandRecord.outOfBandInvitation

        (aliceCredentialRecord, _) = try await aliceAgent.oob.receiveInvitation(invitation, config: receiveInvitationConfig)
        XCTAssertEqual(aliceCredentialRecord.state, .OfferReceived)
    }
}
