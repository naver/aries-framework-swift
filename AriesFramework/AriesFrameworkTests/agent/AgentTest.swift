
import XCTest
@testable import AriesFramework
import Indy

class AgentTest: XCTestCase {
    let mediatorInvitationUrl = "http://localhost:3001/invitation"
    let agentInvitationUrl = "http://localhost:3002/invitation"
    func testMediatorConnect() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice", useLedgerSerivce: false)
        config.mediatorPickupStrategy = .Implicit
        config.mediatorConnectionsInvite = "https://public.mediator.indiciotech.io?c_i=eyJAdHlwZSI6ICJkaWQ6c292OkJ6Q2JzTlloTXJqSGlxWkRUVUFTSGc7c3BlYy9jb25uZWN0aW9ucy8xLjAvaW52aXRhdGlvbiIsICJAaWQiOiAiMDVlYzM5NDItYTEyOS00YWE3LWEzZDQtYTJmNDgwYzNjZThhIiwgInNlcnZpY2VFbmRwb2ludCI6ICJodHRwczovL3B1YmxpYy5tZWRpYXRvci5pbmRpY2lvdGVjaC5pbyIsICJyZWNpcGllbnRLZXlzIjogWyJDc2dIQVpxSktuWlRmc3h0MmRIR3JjN3U2M3ljeFlEZ25RdEZMeFhpeDIzYiJdLCAibGFiZWwiOiAiSW5kaWNpbyBQdWJsaWMgTWVkaWF0b3IifQ=="
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                if mediationRecord.state == .Granted {
                    expectation.fulfill()
                } else {
                    XCTFail("mediation failed")
                }
            }
        }

        let expectation = TestHelper.expectation(description: "mediator connected")
        let agent = Agent(agentConfig: config, agentDelegate: TestDelegate(expectation: expectation))
        try await agent.initialize()
        try await TestHelper.wait(for: expectation, timeout: 5)
        try await agent.reset()
    }

    func testAgentInit() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice", useLedgerSerivce: false)
        config.mediatorConnectionsInvite = try String(data: Data(contentsOf: URL(string: mediatorInvitationUrl)!), encoding: .utf8)!
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                if mediationRecord.state == .Granted {
                    expectation.fulfill()
                } else {
                    XCTFail("mediation failed")
                }
            }
        }

        // test init with mediator

        let expectation = TestHelper.expectation(description: "mediator connected")
        var agent = Agent(agentConfig: config, agentDelegate: TestDelegate(expectation: expectation))
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)

        // test init with mediator after shutdown

        try await agent.shutdown()
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)
        try await agent.reset()

        // test init without mediator

        config.mediatorConnectionsInvite = nil
        agent = Agent(agentConfig: config, agentDelegate: nil)
        XCTAssertEqual(agent.isInitialized(), false)
        try await agent.initialize()
        XCTAssertEqual(agent.isInitialized(), true)
        try await agent.reset()
        XCTAssertEqual(agent.isInitialized(), false)
    }

    /*
     Run two javascript mediators as follows:
       $ AGENT_ENDPOINTS=http://localhost:3001 npx ts-node mediator.ts
       $ AGENT_PORT=3002 AGENT_ENDPOINTS=http://localhost:3002 npx ts-node mediator.ts
     */
    func testAgentConnect() async throws {
        var config = try TestHelper.getBaseConfig(name: "alice", useLedgerSerivce: false)
        config.mediatorConnectionsInvite = String(data: try Data(contentsOf: URL(string: mediatorInvitationUrl)!), encoding: .utf8)!
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation
            let invitation: ConnectionInvitationMessage
            var connectionCount = 0
            var connectionCommand: ConnectionCommand?
            init(expectation: TestHelper.XCTestExpectation, invitation: ConnectionInvitationMessage) {
                self.expectation = expectation
                self.invitation = invitation
            }
            func setCommand(command: ConnectionCommand?) {
                self.connectionCommand = command
            }
            func onConnectionStateChanged(connectionRecord: ConnectionRecord) {
                print("connection state changed to \(connectionRecord.state)")
                if (connectionRecord.state == .Complete) {
                    connectionCount += 1
                    if (connectionCount == 2) {
                        expectation.fulfill()
                    } else if (connectionCount == 3) {
                        XCTFail("Too many connections")
                    }
                }
            }
            func onMediationStateChanged(mediationRecord: MediationRecord) {
                print("mediation state changed to \(mediationRecord.state)")
                XCTAssertEqual(mediationRecord.state, .Granted)
                Task {
                    _ = try? await connectionCommand!.receiveInvitation(invitation)
                }
            }
        }

        let anotherInvite = String(data: try Data(contentsOf: URL(string: agentInvitationUrl)!), encoding: .utf8)!
        let invitation = try ConnectionInvitationMessage.fromUrl(anotherInvite)

        let expectation = TestHelper.expectation(description: "Two connections are made")
        let testDelegate = TestDelegate(expectation: expectation, invitation: invitation)
        let agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        testDelegate.setCommand(command: agent.connections)
        try await agent.initialize()
        try await TestHelper.wait(for: expectation, timeout: 5)
        try await agent.reset()
    }

    // Run faber in AFJ/demo/ with websocket endpoint and offer credential
    func testDemoFaber() async throws {
        class TestDelegate: AgentDelegate {
            let expectation: TestHelper.XCTestExpectation

            init(expectation: TestHelper.XCTestExpectation) {
                self.expectation = expectation
            }

            func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
                print("credential state changed to \(credentialRecord.state)")
                if (credentialRecord.state == .Done) {
                    expectation.fulfill()
                }
            }
        }

        let config = try TestHelper.getBcovinConfig(name: "alice")
        let expectation = TestHelper.expectation(description: "credential received")
        let testDelegate = TestDelegate(expectation: expectation)
        let agent = Agent(agentConfig: config, agentDelegate: testDelegate)
        try await agent.initialize()

        print("Getting invitation from faber")
        let faberInvitationUrl = "http://localhost:9001/invitation"
        let faberInvite = String(data: try Data(contentsOf: URL(string: faberInvitationUrl)!), encoding: .utf8)!
        let invitation = try ConnectionInvitationMessage.fromUrl(faberInvite)
        print("Start connecting to faber")
        _ = try await agent.connections.receiveInvitation(invitation)

        try await TestHelper.wait(for: expectation, timeout: 120)
        try await agent.reset()
    }
}
