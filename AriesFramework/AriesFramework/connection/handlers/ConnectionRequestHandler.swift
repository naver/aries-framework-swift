
import Foundation

class ConnectionRequestHandler: MessageHandler {
    let agent: Agent
    let messageType = ConnectionRequestMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        guard let recipientKey = messageContext.recipientVerkey, let _ = messageContext.senderVerkey else {
            throw AriesFrameworkError.frameworkError("Unable to process connection request without senderVerkey or recipientVerkey")
        }

        guard var connectionRecord = try await agent.connectionService.findByInvitationKey(recipientKey) else {
            throw AriesFrameworkError.frameworkError("Connection for recipientKey \(recipientKey) not found!")
        }

        var routing: Routing?
        if connectionRecord.multiUseInvitation {
            routing = try await agent.mediationRecipient.getRouting()
        }

        connectionRecord = try await agent.connectionService.processRequest(messageContext: messageContext, routing: routing)

        if connectionRecord.autoAcceptConnection ?? false || agent.agentConfig.autoAcceptConnections {
            return try await agent.connectionService.createResponse(connectionId: connectionRecord.id)
        }

        return nil
    }
}
