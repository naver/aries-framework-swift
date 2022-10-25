//
//  WalletOpener.swift
//  wallet-app-ios
//

import SwiftUI
import Indy
import AriesFramework

final class WalletState: ObservableObject {
  @Published var walletOpened: Bool = false
}

var agent: Agent?

class WalletOpener : ObservableObject {

    func openWallet(walletState: WalletState) async {
        let userDefaults = UserDefaults.standard
        var key = userDefaults.value(forKey:"walletKey") as? String
        if (key == nil) {
            do {
                key = try await IndyWallet.generateKey(forConfig: nil)
                userDefaults.set(key, forKey: "walletKey")
            } catch {
                if let err = error as NSError? {
                    print("Cannot generate key: \(err.userInfo["message"] ?? "Unknown error")")
                    return
                }
            }
        }

//        let invitationUrl = "http://localhost:3001/invitation?c_i=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wL2ludml0YXRpb24iLCJAaWQiOiJlZDM1YzRlZS1hZjA2LTQ4M2ItOGEyZC1jMGY5YTk4ZTZjYTEiLCJsYWJlbCI6IkFyaWVzIEZyYW1ld29yayBKYXZhU2NyaXB0IE1lZGlhdG9yIiwicmVjaXBpZW50S2V5cyI6WyI2cDlKc0xCRlRveW5wRDR0a3RpU3VEQ0hETUVQd0FWUndmRGZSRWVnZUVDMSJdLCJzZXJ2aWNlRW5kcG9pbnQiOiJodHRwOi8vbG9jYWxob3N0OjMwMDEiLCJyb3V0aW5nS2V5cyI6W119"
        let invitationUrl: String? = nil
        let genesisPath = Bundle(for: WalletOpener.self).path(forResource: "bcovrin-genesis", ofType: "txn")
        let config = AgentConfig(walletKey: key!,
            genesisPath: genesisPath!,
            mediatorConnectionsInvite: invitationUrl,
            label: "SampleApp",
            autoAcceptCredential: .never,
            autoAcceptProof: .never)

        do {
            agent = Agent(agentConfig: config, agentDelegate: CredentialHandler.shared)
            try await agent!.initialize()
        } catch {
            print("Cannot initialize agent: \(error)")
            return
        }

        print("Wallet opened!")
        DispatchQueue.main.async {
            withAnimation { walletState.walletOpened = true }
        }
    }
}
