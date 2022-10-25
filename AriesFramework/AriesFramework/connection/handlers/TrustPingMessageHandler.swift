
import Foundation

class TrustPingMessageHandler: MessageHandler {
    let agent: Agent
    let messageType = TrustPingMessage.type

    init(agent: Agent) {
        self.agent = agent
    }

    func handle(messageContext: InboundMessageContext) async throws -> OutboundMessage? {
        // Just ignore the TrustPingMessage
        return nil
    }
}
