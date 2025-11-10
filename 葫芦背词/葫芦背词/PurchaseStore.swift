import Foundation
import StoreKit

enum SubscriptionTier: Equatable {
    case none
    case plus  // Monthly subscription
    case pro   // Yearly subscription
}

@MainActor
final class PurchaseStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var subscriptionTier: SubscriptionTier = .none
    @Published private(set) var subscriptionExpirationDate: Date? = nil
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var previousSubscriptionTier: SubscriptionTier = .none

    private var updatesTask: Task<Void, Never>? = nil

    private let previousTierKey = "previousSubscriptionTier"
    private let lastExpirationDateKey = "lastSubscriptionExpirationDate"

    // Check if subscription will expire within 7 days
    var isExpiringSoon: Bool {
        guard let expirationDate = subscriptionExpirationDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiry <= 7 && daysUntilExpiry >= 0
    }

    // Check if subscription has expired
    var hasExpired: Bool {
        // Check if we have a stored expiration date
        let storedExpiryDate = UserDefaults.standard.object(forKey: lastExpirationDateKey) as? Date
        let expiryDate = subscriptionExpirationDate ?? storedExpiryDate

        guard let expirationDate = expiryDate else { return false }
        return !isPremium && expirationDate < Date() && previousSubscriptionTier != .none
    }

    init() {
        // Load saved previous tier
        if let savedTierRaw = UserDefaults.standard.string(forKey: previousTierKey) {
            switch savedTierRaw {
            case "plus":
                previousSubscriptionTier = .plus
            case "pro":
                previousSubscriptionTier = .pro
            default:
                previousSubscriptionTier = .none
            }
        }

        // Load saved expiration date if current is nil
        if subscriptionExpirationDate == nil,
           let savedDate = UserDefaults.standard.object(forKey: lastExpirationDateKey) as? Date {
            subscriptionExpirationDate = savedDate
        }

        Task { await refreshEntitlements() }
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let ids: Set<String> = [
                AppEntitlements.ProductID.premiumMonthly,
                AppEntitlements.ProductID.premiumYearly
            ]
            print("[IAP] Loading products for ids: \(Array(ids))")
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted(by: { ($0.price as NSDecimalNumber).doubleValue < ($1.price as NSDecimalNumber).doubleValue })
            print("[IAP] Loaded products: \(products.map { $0.id })")
            if products.isEmpty {
                lastError = "No products returned by StoreKit. Ensure the Run scheme has StoreKit.storekit selected, and Simulator Settings → Developer → StoreKit Testing is enabled."
                print("[IAP] No products returned. Tips: 1) Edit Scheme → Run → Options → StoreKit Configuration (pick StoreKit.storekit). 2) Simulator Settings → Developer → StoreKit Testing → Enable. 3) If still empty, remove any custom Launch Arguments that override distributor, and try Clean Build Folder.")
            } else {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
            print("[IAP] loadProducts error: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do { try await AppStore.sync() } catch { lastError = error.localizedDescription }
        await refreshEntitlements()
    }

    func status(for product: Product) async -> Product.SubscriptionInfo.Status? {
        guard case .autoRenewable = product.type else { return nil }
        do {
            return try await product.subscription?.status.first
        } catch { return nil }
    }

    private func refreshEntitlements() async {
        var premium = false
        var tier: SubscriptionTier = .none
        var expiryDate: Date? = nil
        var foundHistoricalSubscription = false

        // Check current entitlements first
        for await ent in Transaction.currentEntitlements {
            if case .verified(let t) = ent {
                if t.productID == AppEntitlements.ProductID.premiumMonthly {
                    premium = true
                    tier = .plus
                    expiryDate = t.expirationDate
                } else if t.productID == AppEntitlements.ProductID.premiumYearly {
                    premium = true
                    tier = .pro
                    expiryDate = t.expirationDate
                }
            }
        }

        // If no current entitlement, check transaction history for expired subscriptions
        if tier == .none {
            print("[IAP] No current entitlement, checking transaction history...")

            for await result in Transaction.all {
                if case .verified(let transaction) = result {
                    if transaction.productID == AppEntitlements.ProductID.premiumMonthly ||
                       transaction.productID == AppEntitlements.ProductID.premiumYearly {

                        let historicalTier: SubscriptionTier = transaction.productID == AppEntitlements.ProductID.premiumYearly ? .pro : .plus

                        // Check if this transaction has expired
                        if let expiry = transaction.expirationDate, expiry < Date() {
                            print("[IAP] Found expired transaction: \(transaction.productID), expiry: \(expiry)")

                            // Use the most recent expired subscription
                            if expiryDate == nil || expiry > expiryDate! {
                                expiryDate = expiry
                                tier = historicalTier
                                foundHistoricalSubscription = true
                            }
                        }
                    }
                }
            }
        }

        // Save subscription info when active
        if tier != .none && premium {
            // Save current tier
            let tierString = tier == .plus ? "plus" : "pro"
            UserDefaults.standard.set(tierString, forKey: previousTierKey)
            previousSubscriptionTier = tier

            // Save expiration date
            if let expiryDate = expiryDate {
                UserDefaults.standard.set(expiryDate, forKey: lastExpirationDateKey)
            }
        } else if foundHistoricalSubscription {
            // Found an expired subscription in history
            let tierString = tier == .plus ? "plus" : "pro"
            UserDefaults.standard.set(tierString, forKey: previousTierKey)
            previousSubscriptionTier = tier

            if let expiryDate = expiryDate {
                UserDefaults.standard.set(expiryDate, forKey: lastExpirationDateKey)
            }
        }

        // When subscription becomes inactive, keep the stored previous tier
        if tier == .none && subscriptionTier != .none {
            // Subscription just expired or was cancelled
            print("[IAP] Subscription expired or cancelled. Previous tier: \(previousSubscriptionTier)")
        }

        isPremium = premium
        subscriptionTier = premium ? tier : .none

        // Keep the last known expiration date even after expiry
        if let expiryDate = expiryDate {
            subscriptionExpirationDate = expiryDate
        } else if !premium {
            // Load from storage if no active subscription
            if let storedDate = UserDefaults.standard.object(forKey: lastExpirationDateKey) as? Date {
                subscriptionExpirationDate = storedDate
            }
        }

        // Debug logging
        print("[IAP] Current status - isPremium: \(isPremium), tier: \(subscriptionTier), previousTier: \(previousSubscriptionTier)")
        if let expiryDate = subscriptionExpirationDate {
            print("[IAP] Subscription expiration date: \(expiryDate), hasExpired: \(hasExpired)")
        } else {
            print("[IAP] No expiration date available")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to verify purchase."])
        case .verified(let safe):
            return safe
        }
    }
}
