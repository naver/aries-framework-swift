
import Foundation
import os

let didCommProfiles = ["didcomm/aip1", "didcomm/aip2;env=rfc19"]

public struct CreateOutOfBandInvitationConfig {
    public var label: String?
    public var alias: String?
    public var imageUrl: String?
    public var goalCode: String?
    public var goal: String?
    public var handshake: Bool?
    public var handshakeProtocols: [HandshakeProtocol]?
    public var messages: [AgentMessage]?
    public var multiUseInvitation: Bool?
    public var autoAcceptConnection: Bool?
    public var routing: Routing?
}

public struct ReceiveOutOfBandInvitationConfig {
    public var label: String?
    public var alias: String?
    public var imageUrl: String?
    public var autoAcceptInvitation: Bool?
    public var autoAcceptConnection: Bool?
    public var reuseConnection: Bool?
    public var routing: Routing?
}

public class OutOfBandCommand {
    let agent: Agent
    let logger = Logger(subsystem: "AriesFramework", category: "OutOfBandCommand")

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: HandshakeReuseHandler(agent: agent))
        dispatcher.registerHandler(handler: HandshakeReuseAcceptedHandler(agent: agent))
    }

    /**
     Creates an outbound out-of-band record containing out-of-band invitation message defined in
     Aries RFC 0434: Out-of-Band Protocol 1.1.

     It automatically adds all supported handshake protocols by agent to `handshake_protocols`. You
     can modify this by setting `handshakeProtocols` in `config` parameter. If you want to create
     invitation without handshake, you can set `handshake` to `false`.

     If `config` parameter contains `messages` it adds them to `requests~attach` attribute.

     Agent role: sender (inviter)

     - Parameter config: configuration of how out-of-band invitation should be created.
     - Returns: out-of-band record.
    */
    public func createInvitation(config: CreateOutOfBandInvitationConfig) async throws -> OutOfBandRecord {
        let multiUseInvitation = config.multiUseInvitation ?? false
        let handshake = config.handshake ?? true
        let customHandshakeProtocols = config.handshakeProtocols
        let autoAcceptConnection = config.autoAcceptConnection ?? agent.agentConfig.autoAcceptConnections
        let messages = config.messages ?? []
        let label = config.label ?? agent.agentConfig.label
        let imageUrl = config.imageUrl ?? agent.agentConfig.connectionImageUrl

        if (!handshake && messages.count == 0) {
            throw AriesFrameworkError.frameworkError(
                "One of handshake_protocols and requests~attach MUST be included in the message."
            )
        }

        if (!handshake && customHandshakeProtocols != nil) {
            throw AriesFrameworkError.frameworkError(
                "Attribute 'handshake' can not be 'false' when 'handshakeProtocols' is defined."
            )
        }

        if (!messages.isEmpty && multiUseInvitation) {
            throw AriesFrameworkError.frameworkError(
                "Attribute 'multiUseInvitation' can not be 'true' when 'messages' is defined."
            )
        }

        var handshakeProtocols: [HandshakeProtocol]?
        if (handshake) {
            if (customHandshakeProtocols != nil) {
                try self.assertHandshakeProtocols(customHandshakeProtocols!)
                handshakeProtocols = customHandshakeProtocols
            } else {
                handshakeProtocols = self.getSupportedHandshakeProtocols()
            }
        }

        var routing: Routing! = config.routing
        if (routing == nil) {
            routing = try await self.agent.mediationRecipient.getRouting()
        }

        let services = routing.endpoints.enumerated().map({ (index, endpoint) -> OutOfBandDidCommService in
            return .oobDidDocument(OutOfBandDidDocumentService(
                id: "#inline-\(index)",
                serviceEndpoint: endpoint,
                recipientKeys: [routing.verkey],
                routingKeys: routing.routingKeys
            ))
        })

        let outOfBandInvitation = OutOfBandInvitation(
            id: OutOfBandInvitation.generateId(),
            label: label,
            goalCode: config.goalCode,
            goal: config.goal,
            accept: didCommProfiles,
            handshakeProtocols: handshakeProtocols,
            services: services,
            imageUrl: imageUrl)

        if (!messages.isEmpty) {
            try messages.forEach { message in
                try outOfBandInvitation.addRequest(message: message)
            }
        }

        let outOfBandRecord = OutOfBandRecord(
            id: OutOfBandRecord.generateId(),
            createdAt: Date(),
            outOfBandInvitation: outOfBandInvitation,
            role: .Sender,
            state: .AwaitResponse,
            reusable: multiUseInvitation,
            autoAcceptConnection: autoAcceptConnection)

        try await self.agent.outOfBandRepository.save(outOfBandRecord)
        agent.agentDelegate?.onOutOfBandStateChanged(outOfBandRecord: outOfBandRecord)

        return outOfBandRecord
    }

    /**
     Creates inbound out-of-band record and assigns out-of-band invitation message to it if the
     message is valid. It automatically passes out-of-band invitation for further processing to
     `acceptInvitation` method. If you don't want to do that you can set `autoAcceptInvitation`
     attribute in `config` parameter to `false` and accept the message later by calling
     `acceptInvitation`.

     It supports both OOB (Aries RFC 0434: Out-of-Band Protocol 1.1) and Connection Invitation
     (0160: Connection Protocol).

     Agent role: receiver (invitee)

     - Parameters:
        - invitation: OutOfBandInvitation to receive.
        - config: configuration of how out-of-band invitation should be received.
     - Returns: out-of-band record and connection record if one has been created.
    */
    public func receiveInvitation(invitation: OutOfBandInvitation, config: ReceiveOutOfBandInvitationConfig?) async throws -> OutOfBandRecord {
        let autoAcceptInvitation = config?.autoAcceptInvitation ?? true
        let autoAcceptConnection = config?.autoAcceptConnection ?? true
        let reuseConnection = config?.reuseConnection ?? false
        let label = config?.label ?? agent.agentConfig.label
        let alias = config?.alias
        let imageUrl = config?.imageUrl ?? agent.agentConfig.connectionImageUrl

        let messages = try invitation.getRequests()

        if (invitation.handshakeProtocols?.count ?? 0 == 0 && messages.count == 0) {
            throw AriesFrameworkError.frameworkError(
                "One of handshake_protocols and requests~attach MUST be included in the message."
            )
        }

        let previousRecord = try await agent.outOfBandRepository.findByInvitationId(invitation.id)
        if previousRecord != nil {
            throw AriesFrameworkError.frameworkError(
                "An out of band record with invitation \(invitation.id) already exists. Invitations should have a unique id."
            )
        }

        let outOfBandRecord = OutOfBandRecord(
            id: OutOfBandRecord.generateId(),
            createdAt: Date(),
            outOfBandInvitation: invitation,
            role: .Receiver,
            state: .Initial,
            reusable: false,
            autoAcceptConnection: autoAcceptConnection)
        try await self.agent.outOfBandRepository.save(outOfBandRecord)
        agent.agentDelegate?.onOutOfBandStateChanged(outOfBandRecord: outOfBandRecord)

        if (autoAcceptInvitation) {
            let acceptConfig = ReceiveOutOfBandInvitationConfig(
                label: label,
                alias: alias,
                imageUrl: imageUrl,
                autoAcceptConnection: autoAcceptConnection,
                reuseConnection: reuseConnection,
                routing: config?.routing)
            return try await self.acceptInvitation(outOfBandRecord: outOfBandRecord, config: acceptConfig)
        }

        return outOfBandRecord
    }

    public func acceptInvitation(outOfBandRecord: OutOfBandRecord, config: ReceiveOutOfBandInvitationConfig?) async throws -> OutOfBandRecord {
        throw AriesFrameworkError.frameworkError(
            "Method 'acceptInvitation' is not implemented yet."
        )
    }


    private func getSupportedHandshakeProtocols() -> [HandshakeProtocol] {
        return [.Connections]
    }

    private func assertHandshakeProtocols(_ handshakeProtocols: [HandshakeProtocol]) throws {
        if (!areHandshakeProtocolsSupported(handshakeProtocols)) {
            let supportedProtocols = getSupportedHandshakeProtocols()
            throw AriesFrameworkError.frameworkError(
                "Handshake protocols [\(handshakeProtocols)] are not supported. Supported protocols are [\(supportedProtocols)]"
            )
        }
    }

    private func areHandshakeProtocolsSupported(_ handshakeProtocols: [HandshakeProtocol]) -> Bool {
        let supportedProtocols = getSupportedHandshakeProtocols()
        return handshakeProtocols.allSatisfy({ (p) -> Bool in
            return supportedProtocols.contains(p)
        })
    }
}
