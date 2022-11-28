
import Foundation

class OutOfBandRepository: Repository<OutOfBandRecord> {
    func findByInvitationId(_ invitationId: String) async throws -> OutOfBandRecord? {
        return try await findSingleByQuery("{\"invitationId\": \"\(invitationId)\"}")
    }

    func findByInvitationKey(_ invitationKey: String) async throws -> OutOfBandRecord? {
        return try await findSingleByQuery("{\"invitationKey\": \"\(invitationKey)\"}")
    }

    func findByFingerprint(_ fingerprint: String) async throws -> OutOfBandRecord? {
        return try await findSingleByQuery("{\"recipientKeyFingerprints\": [\"\(fingerprint)\"]}")
    }
}
