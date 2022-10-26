
import Foundation
import os

class MediationRecipient {
    let logger = Logger(subsystem: "AriesFramework", category: "MediationRecipient")
    let agent: Agent
    let repository: MediationRepository
    var messagePickupInitiated = false
    var keylistUpdateDone = false
    var pickupTimer: Timer?

    init(agent: Agent, dispatcher: Dispatcher) {
        self.agent = agent
        self.repository = MediationRepository(agent: agent)
        registerHandlers(dispatcher: dispatcher)
    }

    func registerHandlers(dispatcher: Dispatcher) {
        dispatcher.registerHandler(handler: MediationGrantHandler(agent: agent))
        dispatcher.registerHandler(handler: MediationDenyHandler(agent: agent))
        dispatcher.registerHandler(handler: BatchHandler(agent: agent))
        dispatcher.registerHandler(handler: KeylistUpdateResponseHandler(agent: agent))
    }

    func initialize(mediatorConnectionsInvite: String) async throws {
        logger.debug("Initialize mediation with invitation: \(mediatorConnectionsInvite)")
        let invitation = try ConnectionInvitationMessage.fromUrl(mediatorConnectionsInvite)

        guard let recipientKey = invitation.recipientKeys?.first else {
            throw AriesFrameworkError.frameworkError("Invalid mediation invitation. Invitation must have at least one recipient key.")
        }

        if let connection = try await agent.connectionService.findByInvitationKey(recipientKey), connection.isReady() {
            try await requestMediationIfNecessry(connection: connection)
        } else {
            let invitationConnectionRecord = try await agent.connectionService.processInvitation(invitation, routing: self.getRouting(), autoAcceptConnection: true)
            let message = try await agent.connectionService.createRequest(connectionId: invitationConnectionRecord.id)
            try await agent.messageSender.send(message: message)
        }
    }

    func close() {
        pickupTimer?.invalidate()
    }

    func requestMediationIfNecessry(connection: ConnectionRecord) async throws {
        if (messagePickupInitiated || agent.agentConfig.mediatorConnectionsInvite == nil) {
            agent.setInitialized()
            return
        }

        if let mediationRecord = try await repository.getDefault() {
            if mediationRecord.isReady() && hasSameInvitationUrl(record: mediationRecord) {
                try await initiateMessagePickup(mediator: mediationRecord)
                agent.setInitialized()
                return
            }

            try await repository.delete(mediationRecord)
        }

        let message = try await createRequest(connection: connection)
        try await agent.messageSender.send(message: message)
    }

    func hasSameInvitationUrl(record: MediationRecord) -> Bool {
        return record.invitationUrl == agent.agentConfig.mediatorConnectionsInvite
    }

    func initiateMessagePickup(mediator: MediationRecord) async throws {
        messagePickupInitiated = true
        let mediatorConnection = try await agent.connectionRepository.getById(mediator.connectionId)
        try await self.pickupMessages(mediatorConnection: mediatorConnection)

        DispatchQueue.main.async {
            self.pickupTimer = Timer.scheduledTimer(withTimeInterval: self.agent.agentConfig.mediatorPollingInterval, repeats: true) { [self] timer in
                Task {
                    try await self.pickupMessages(mediatorConnection: mediatorConnection)
                }
            }
        }
    }

    func pickupMessages(mediatorConnection: ConnectionRecord) async throws {
        try mediatorConnection.assertReady()

        let batchPickupMessage = BatchPickupMessage(batchSize: 10)
        let message = OutboundMessage(payload: batchPickupMessage, connection: mediatorConnection)
        try await agent.messageSender.send(message: message)
    }

    func pickupMessages() async throws {
        if (messagePickupInitiated || agent.agentConfig.mediatorConnectionsInvite == nil) {
            return
        }

        guard let mediator = try await repository.getDefault() else {
            throw AriesFrameworkError.frameworkError("Mediator is not ready.")
        }
        let mediatorConnection = try await agent.connectionRepository.getById(mediator.connectionId)
        try await pickupMessages(mediatorConnection: mediatorConnection)
    }

    func getRouting() async throws -> Routing {
        let mediator = try await repository.getDefault()
        let endpoints = mediator?.endpoint == nil ? agent.agentConfig.endpoints : [mediator!.endpoint!]
        let routingKeys = mediator?.routingKeys ?? []

        let (did, verkey) = try await agent.wallet.createDid()
        if mediator != nil && mediator!.isReady() {
            try await keylistUpdate(mediator: mediator!, verkey: verkey)
        }

        return Routing(endpoints: endpoints, verkey: verkey, did: did, routingKeys: routingKeys, mediatorId: mediator?.id)
    }

    func createRequest(connection: ConnectionRecord) async throws -> OutboundMessage {
        let message = MediationRequestMessage(sentTime: Date())
        let mediationRecord = MediationRecord(state: .Requested, role: .Mediator, connectionId: connection.id, threadId: connection.id, invitationUrl: agent.agentConfig.mediatorConnectionsInvite!)
        try await repository.save(mediationRecord)

        return OutboundMessage(payload: message, connection: connection)
    }

    func processMediationGrant(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        var mediationRecord = try await repository.getByConnectionId(connection.id)
        let decoder = JSONDecoder()
        let message = try decoder.decode(MediationGrantMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        try mediationRecord.assertState(.Requested)

        mediationRecord.endpoint = message.endpoint
        mediationRecord.routingKeys = message.routingKeys
        mediationRecord.state = .Granted
        try await repository.update(mediationRecord)
        agent.setInitialized()
        agent.agentDelegate?.onMediationStateChanged(mediationRecord: mediationRecord)
        try await initiateMessagePickup(mediator: mediationRecord)
    }

    func processMediationDeny(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        var mediationRecord = try await repository.getByConnectionId(connection.id)
        try mediationRecord.assertState(.Requested)

        mediationRecord.state = .Denied
        try await repository.update(mediationRecord)
        agent.agentDelegate?.onMediationStateChanged(mediationRecord: mediationRecord)
    }

    func processBatchMessage(messageContext: InboundMessageContext) async throws {
        if (messageContext.connection == nil) {
            throw AriesFrameworkError.frameworkError("No connection associated with incoming message with id \(messageContext.message.id)")
        }

        let decoder = JSONDecoder()
        let message = try decoder.decode(BatchMessage.self, from: Data(messageContext.plaintextMessage.utf8))

        logger.debug("Get \(message.messages.count) batch messages")
        let forwardedMessages = message.messages
        for forwardedMessage in forwardedMessages {
            try await agent.messageReceiver.receiveMessage(forwardedMessage.message)
        }
    }

    func processKeylistUpdateResults(messageContext: InboundMessageContext) async throws {
        let connection = try messageContext.assertReadyConnection()
        let mediationRecord = try await repository.getByConnectionId(connection.id)
        try mediationRecord.assertReady()

        let decoder = JSONDecoder()
        let message = try decoder.decode(KeylistUpdateResponseMessage.self, from: Data(messageContext.plaintextMessage.utf8))
        for update in message.updated {
            if (update.action == .add) {
                logger.info("Key \(update.recipientKey) added to keylist")
            } else if (update.action == .remove) {
                logger.info("Key \(update.recipientKey) removed from keylist")
            }
        }
        keylistUpdateDone = true
    }

    func keylistUpdate(mediator: MediationRecord, verkey: String) async throws {
        try mediator.assertReady()
        let keylistUpdateMessage = KeylistUpdateMessage(updates: [KeylistUpdate(recipientKey: verkey, action: .add)])
        let connection = try await agent.connectionRepository.getById(mediator.connectionId)
        let message = OutboundMessage(payload: keylistUpdateMessage, connection: connection)

        keylistUpdateDone = false
        try await agent.messageSender.send(message: message)
        if (!keylistUpdateDone) {
            // This is not guaranteed when the outbound transport is WebSocket.
            // throw AriesFrameworkError.frameworkError("Keylist update not finished")
            logger.warning("Keylist update not finished")
        }
    }
}
