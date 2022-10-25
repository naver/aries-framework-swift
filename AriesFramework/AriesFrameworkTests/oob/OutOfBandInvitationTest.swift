
import XCTest
@testable import AriesFramework

class OutOfBandInvitationTest: XCTestCase {
    func testToUrl() throws {
        let domain = "https://example.com/ssi"
        let jsonObject = [
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "services": ["did:sov:LjgpST2rjsoxYegQDRm7EL"],
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
        ] as [String : Any]
        let json = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let invitation = try JSONDecoder().decode(OutOfBandInvitation.self, from: json)
        let invitationUrl = try invitation.toUrl(domain: domain)

        let decodedInvitation = try OutOfBandInvitation.fromUrl(invitationUrl)
        XCTAssertEqual(invitation.id, decodedInvitation.id)
        XCTAssertEqual(invitation.type, decodedInvitation.type)
        XCTAssertEqual(invitation.label, decodedInvitation.label)
        XCTAssertEqual(invitation.goalCode, decodedInvitation.goalCode)
        XCTAssertEqual(invitation.goal, decodedInvitation.goal)
        XCTAssertEqual(invitation.handshakeProtocols, decodedInvitation.handshakeProtocols)
    }

    func testFromUrl() throws {
        let invitationUrl = "http://example.com/ssi?oob=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvb3V0LW9mLWJhbmQvMS4xL2ludml0YXRpb24iLCJAaWQiOiI2OTIxMmEzYS1kMDY4LTRmOWQtYTJkZC00NzQxYmNhODlhZjMiLCJsYWJlbCI6IkZhYmVyIENvbGxlZ2UiLCJnb2FsX2NvZGUiOiJpc3N1ZS12YyIsImdvYWwiOiJUbyBpc3N1ZSBhIEZhYmVyIENvbGxlZ2UgR3JhZHVhdGUgY3JlZGVudGlhbCIsImhhbmRzaGFrZV9wcm90b2NvbHMiOlsiaHR0cHM6Ly9kaWRjb21tLm9yZy9kaWRleGNoYW5nZS8xLjAiLCJodHRwczovL2RpZGNvbW0ub3JnL2Nvbm5lY3Rpb25zLzEuMCJdLCJzZXJ2aWNlcyI6WyJkaWQ6c292OkxqZ3BTVDJyanNveFllZ1FEUm03RUwiXX0K"
        let invitation = try OutOfBandInvitation.fromUrl(invitationUrl)

        XCTAssertEqual(invitation.id, "69212a3a-d068-4f9d-a2dd-4741bca89af3")
        XCTAssertEqual(invitation.type, "https://didcomm.org/out-of-band/1.1/invitation")
        XCTAssertEqual(invitation.label, "Faber College")
        XCTAssertEqual(invitation.goalCode, "issue-vc")
        XCTAssertEqual(invitation.goal, "To issue a Faber College Graduate credential")
        XCTAssertEqual(invitation.handshakeProtocols, [HandshakeProtocol.DidExchange, HandshakeProtocol.Connections])
        if case .did(let did) = invitation.services[0] {
            XCTAssertEqual(did, "did:sov:LjgpST2rjsoxYegQDRm7EL")
        } else {
            XCTFail("Expected did service")
        }
    }

    func testFromJson() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": ["did:sov:LjgpST2rjsoxYegQDRm7EL"]
        }
        """
        let invitation = try OutOfBandInvitation.fromJson(json)
        XCTAssertEqual(invitation.label, "Faber College")
    }

    func testInvitationWithService() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": [
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "routingKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "serviceEndpoint": "https://example.com/ssi",
                }
            ]
        }
        """

        let invitation = try OutOfBandInvitation.fromJson(json)
        if case .oobDidDocument(let didDocument) = invitation.services[0] {
            XCTAssertEqual(didDocument.id, "#inline")
            XCTAssertEqual(didDocument.recipientKeys[0], "did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th")
            XCTAssertEqual(didDocument.routingKeys?[0], "did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th")
            XCTAssertEqual(didDocument.serviceEndpoint, "https://example.com/ssi")
        } else {
            XCTFail("Expected OutOfBandDidDocumentService service")
        }
    }

    func testFingerprints() throws {
        let json: String = """
        {
            "@type": "https://didcomm.org/out-of-band/1.1/invitation",
            "@id": "69212a3a-d068-4f9d-a2dd-4741bca89af3",
            "label": "Faber College",
            "goal_code": "issue-vc",
            "goal": "To issue a Faber College Graduate credential",
            "handshake_protocols": ["https://didcomm.org/didexchange/1.0", "https://didcomm.org/connections/1.0"],
            "services": [
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th"],
                    "serviceEndpoint": "https://example.com/ssi",
                },
                "did:sov:LjgpST2rjsoxYegQDRm7EL",
                {
                    "id": "#inline",
                    "type": "did-communication",
                    "recipientKeys": ["did:key:123", "did:key:456"],
                    "serviceEndpoint": "https://example.com/ssi",
                }
            ]
        }
        """

        let invitation = try OutOfBandInvitation.fromJson(json)
        XCTAssertEqual(try invitation.fingerprints(), ["z6MkmjY8GnV5i9YTDtPETC2uUAW6ejw3nk5mXF5yci5ab7th", "123", "456"])
    }

    func testRequests() throws {
        let invitation = OutOfBandInvitation(id: "test", label: "test invitation")
        let trustPing = TrustPingMessage(comment: "hello")
        try invitation.addRequest(message: trustPing)
        let requests = try invitation.getRequests()
        XCTAssertEqual(requests.count, 1)

        let request = try JSONDecoder().decode(TrustPingMessage.self, from: requests[0].data(using: .utf8)!)
        XCTAssertEqual(request.comment, "hello")
    }
}
