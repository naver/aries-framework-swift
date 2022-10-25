
import Foundation

public enum OutOfBandRole: String, Codable {
    case Sender = "sender"
    case Receiver = "receiver"
}

public enum OutOfBandState: String, Codable {
    case Initial = "initial"
    case AwaitResponse = "await-response"
    case PrepareResponse = "prepare-response"
    case Done = "done"
}
