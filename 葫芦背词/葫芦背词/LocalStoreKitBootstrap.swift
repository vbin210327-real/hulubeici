import Foundation

#if DEBUG
import StoreKit
#if canImport(StoreKitTest)
import StoreKitTest
#endif
import SwiftUI

@MainActor
enum LocalStoreKitBootstrap {
    /// Attempts to programmatically enable local StoreKit testing on Simulator using
    /// the StoreKit.storekit embedded in the app bundle. This is a safety net in case
    /// the scheme's "Run → Options → StoreKit Configuration" is not applied.
    static func activateIfPossible() {
        #if targetEnvironment(simulator)
        print("[IAP] LocalStoreKitBootstrap: Running on Simulator")
        print("[IAP] LocalStoreKitBootstrap: Searching for StoreKit.storekit in bundle...")
        print("[IAP] LocalStoreKitBootstrap: Bundle path: \(Bundle.main.bundlePath)")

        // List all .storekit files in bundle for debugging
        if let bundleURL = Bundle.main.resourceURL {
            let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil)
            var foundFiles: [String] = []
            while let file = enumerator?.nextObject() as? URL {
                if file.pathExtension == "storekit" {
                    foundFiles.append(file.path)
                }
            }
            print("[IAP] LocalStoreKitBootstrap: Found .storekit files: \(foundFiles)")
        }

        #if canImport(StoreKitTest)
        print("[IAP] LocalStoreKitBootstrap: StoreKitTest framework is available")
        do {
            guard let url = Bundle.main.url(forResource: "StoreKit", withExtension: "storekit") else {
                print("[IAP] LocalStoreKitBootstrap: ⚠️ StoreKit.storekit not found in app bundle.")
                print("[IAP] LocalStoreKitBootstrap: Please verify target membership in Xcode.")
                return
            }
            print("[IAP] LocalStoreKitBootstrap: Found StoreKit.storekit at: \(url.path)")
            let session = try SKTestSession(contentsOf: url)
            // Make tests stable and clean
            session.clearTransactions()
            session.resetToDefaultState()
            session.disableDialogs = false
            session.askToBuyEnabled = false
            print("[IAP] LocalStoreKitBootstrap: ✅ Activated local StoreKit test session from bundle file.")
        } catch {
            print("[IAP] LocalStoreKitBootstrap: ❌ Error: \(error.localizedDescription)")
            print("[IAP] LocalStoreKitBootstrap: Full error: \(error)")
        }
        #else
        print("[IAP] LocalStoreKitBootstrap: ⚠️ StoreKitTest not available at runtime.")
        print("[IAP] Hint: Either enable Scheme → Run → Options → StoreKit Configuration, or weak‑link StoreKitTest.framework to allow programmatic SKTestSession on Simulator.")
        #endif
        #else
        print("[IAP] LocalStoreKitBootstrap: Running on real device. Enable from Settings → Developer → StoreKit Testing.")
        #endif
    }
}
#endif
