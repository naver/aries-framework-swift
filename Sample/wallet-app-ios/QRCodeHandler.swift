//
//  QRCodeHandler.swift
//  wallet-app-ios
//

import SwiftUI
import QRScanner

class QRCodeHandler: QRScannerViewDelegate {
    let credentialHandler = CredentialHandler.shared
    
    public func receiveInvitation(url: String) {
        Task {
            do {
                let connection = try await agent!.connections.receiveInvitationFromUrl(url)
                await credentialHandler.showSimpleAlert(message: "Connected with \(connection.theirLabel ?? "unknown agent")")
            } catch {
                print(error)
                await credentialHandler.reportError()
            }
        }
    }

    func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: QRScannerError) {
        print(error)
    }

    @MainActor func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String) {
        print(code)
        credentialHandler.menu = nil
        receiveInvitation(url: code)
    }
}
