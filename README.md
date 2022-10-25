# Aries Framework Swift

Aries Framework Swift is an iOS framework for [Aries](https://github.com/hyperledger/aries) protocol.

## Features

Aries Framework Swift supports most of [AIP 1.0](https://github.com/hyperledger/aries-rfcs/tree/main/concepts/0302-aries-interop-profile#aries-interop-profile-version-10) features for mobile agents.

### Supported features
- Connection Protocol
- Mediator Receipient Protocol
- HTTP & WebSocket Transport
- Basic Message Protocol
- Issue Credential Protocol v1
- Present Proof Protocol v1

### Not supported
- Report problem
- Service decorator

### Under development
- DID Exchange Protocol (AIP 2.0)
- Out of Band Protocol (AIP 2.0)

## Requirements & Installation

Aries Framework Swift requires iOS 15.0+ and distributed as a CocoaPods pod.

Add the following lines at the top of the Podfile:
```
source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/naver/indy-sdk.git'
```

And add a pod depencency to the Podfile:
```
pod 'AriesFramework'
```

Building on Apple silicon Mac is not supported yet.

## Usage

App development using Aries Framework Swift is done in following steps:
1. Create an Agent instance
2. Create a connection with another agent by receiving a connection invitation
3. Receive credentials or proof requests by implementing a AgentDelegate

### Create an Agent instance

```swift
    import AriesFramework

    let config = AgentConfig(walletKey: key,
        genesisPath: genesisPath,
        mediatorConnectionsInvite: mediatorInvitationUrl,
        label: "SampleApp",
        autoAcceptCredential: .never,
        autoAcceptProof: .never)

    let agent = Agent(agentConfig: config, agentDelegate: myAgentDelegate)
    try await agent.initialize()
```

To create an agent, first create a key to encrypt the wallet and save it in the keychain.
```swift
    import Indy

    key = try await IndyWallet.generateKey(forConfig: nil)
```

A genesis file for the indy pool should be included as a resource in the app bundle and get the path to it.
```swift
    let genesisPath = Bundle.main.path(forResource: "genesis", ofType: "txn")
```

If you want to use a mediator, set the mediatorConnectionsInvite in the config.
You can use websocket transport without a mediator, but you will need a mediator if the counterparty agent only supports http transport.

`agentDelegate` can be nil if you don't want to receive any events from the agent.

### Create a connection

Create a connection by receiving a connection invitation.
```swift
    let connection = try await agent.connections.receiveInvitationFromUrl(invitationUrl)
```

You will generally get the invitation url by QR code scanning.
Once the connection is created, it is stored in the wallet and your counterparty agent can send you a credential or a proof request using the connection at any time. The connection record contains keys to encrypt or decrypt messages exchanged through the connection.

### Receive credentials or proof requests

Implement `AgentDelegate` to receive events from the agent and use `agent.credentials` or `agent.proofs` commands to handle the requests.

```swift
class MyAgentDelegate: AgentDelegate {
    func onCredentialStateChanged(credentialRecord: CredentialExchangeRecord) {
        if credentialRecord.state == .OfferReceived {
            processCredentialOffer(credentialRecord)
        } else if credentialRecord.state == .Done {
            showSimpleAlert(message: "Credential received")
        }
    }

    func onProofStateChanged(proofRecord: ProofExchangeRecord) {
        if proofRecord.state == .RequestReceived {
            processProofRequest(proofRecord)
        } else if proofRecord.state == .Done {
            showSimpleAlert(message: "Proof done")
        }
    }

    func processCredentialOffer(_ credentialRecord: CredentialExchangeRecord) {
        Task {
            do {
                _ = try await agent.credentials.acceptOffer(options: AcceptOfferOptions(credentialRecordId: credentialRecord.id, autoAcceptCredential: .always))
            } catch {
                showSimpleAlert(message: "Failed to receive credential")
                print(error)
            }
        }
    }

    func processProofRequest(_ proofRecord: ProofExchangeRecord) {
        Task {
            do {
                let retrievedCredentials = try await agent.proofs.getRequestedCredentialsForProofRequest(proofRecordId: proofRecord.id)
                let requestedCredentials = try await agent.proofService.autoSelectCredentialsForProofRequest(retrievedCredentials: retrievedCredentials)
                _ = try await agent!.proofs.acceptRequest(proofRecordId: proofRecord.id, requestedCredentials: requestedCredentials)
            } catch {
                showSimpleAlert(message: "Failed to present proof")
                print(error)
            }
        }
    }
}
```

If you set `autoAcceptCredential` and `autoAcceptProof` to `.always` in the config, it will be done automatically and you don't need to implement a delegate.

Another way to handle those requests is to implement your own `MessageHandler` class and register it to the agent.
```swift
    let messageHandler = MyOfferCredentialHandler()
    agent.dispatcher.registerHandler(handler: messageHandler)
```

For your information, Aries Framework Swift refers to [Aries Framework JavaScript](https://github.com/hyperledger/aries-framework-javascript) a lot, so the class name and API are almost the same.

## Sample App

`Sample` directory contains an iOS sample app that demonstrates how to use Aries Framework Swift. The app receives a connection invitation from a QR code or from a URL input and handles credential offers and proof requests.

To run the sample app, first install the dependencies using CocoaPods.
```bash
$ cd Sample
$ pod install
```

Then open `wallet-app-ios.xcworkspace` and run the app. The agent is created in the `WalletOpener.swift` file and you can set a mediator connection invitation url there, if you want.

There are two genesis files in the `resources` directory.
- `bcovrin-genesis.txn` is for the [GreenLight Dev Ledger](http://dev.greenlight.bcovrin.vonx.io/)
- `local-genesis.txn` is for the local indy-pool.

## Contributing

We welcome contributions to Aries Framework Swift. Please see our [Developer Guide](DEVELOP.md) for more information.

## License

Aries Framework Swift is licensed under the [Apache License 2.0](LICENSE).

```
   Copyright (c) 2022-present NAVER Corp.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```
