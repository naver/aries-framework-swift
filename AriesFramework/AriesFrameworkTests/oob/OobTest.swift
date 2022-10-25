
import XCTest
@testable import AriesFramework

class OobTest: XCTestCase {

    var faberAgent: Agent!
    let makeConnectionConfig = CreateOutOfBandInvitationConfig(
        label: "Faber College",
        goalCode: "p2p-messaging",
        goal: "To make a connection")

    override func setUp() async throws {
        try await super.setUp()

        let faberConfig = try TestHelper.getBaseConfig(name: "faber")
        faberAgent = Agent(agentConfig: faberConfig, agentDelegate: nil)
        try await faberAgent.initialize()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try await faberAgent.reset()
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

        XCTAssertTrue(outOfBandRecord.outOfBandInvitation.handshakeProtocols!.contains(.Connections))
        XCTAssertEqual(try outOfBandRecord.outOfBandInvitation.getRequests().count, 1)
    }
}
