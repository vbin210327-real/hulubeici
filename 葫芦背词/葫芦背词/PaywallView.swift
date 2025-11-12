import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var selectedProductID: String? = AppEntitlements.ProductID.premiumMonthly
    @State private var showHint: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("解锁高效背词")
                    .font(.system(size: 26, weight: .bold))
                Text("无限自定义词书 · 进度面板 · 高级功能")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            features

            pricing

            primaryActionButton

            if let err = purchaseStore.lastError, !err.isEmpty {
                Text("错误：\(err)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if selectedProduct() == nil {
                Text("正在加载商店价格… 若无响应，请检查 Scheme → Run → Options 是否选择了 StoreKit.storekit")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            restorePurchasesButton

            legalLinks

            Button(action: { dismiss() }) {
                Text("稍后再说")
                    .font(.footnote)
            }
            .padding(.bottom, 10)
        }
        .padding(20)
        .task { await purchaseStore.loadProducts() }
        .onChange(of: purchaseStore.isPremium) { _, premium in
            if premium { dismiss() }
        }
        .alert(isPresented: $showHint) {
            Alert(title: Text("未能发起购买"),
                  message: Text("尚未加载到产品信息。请稍候或确认已在 Scheme → Run → Options 选择 StoreKit.storekit，并且产品 ID 与代码一致。"),
                  dismissButton: .default(Text("好的")))
        }
    }

    private var features: some View {
            VStack(alignment: .leading, spacing: 12) {
                featureRow("完整的葫芦背词功能")
                featureRow("无限次一键导入单词")
                featureRow("24 小时在线 AI 助手")
                featureRow("涵盖初中到托福词书")
            }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            Text(text).font(.subheadline)
        }
    }

    private var pricing: some View {
        VStack(spacing: 12) {
            if purchaseStore.products.isEmpty {
                // 显示占位卡片，但不显示右侧“¥…”占位价格
                selectablePlaceholderTile(id: AppEntitlements.ProductID.premiumMonthly,
                                          title: "Plus 月度（含试用）",
                                          note: "目标价格：¥9/月（以商店显示为准）")
                selectablePlaceholderTile(id: AppEntitlements.ProductID.premiumYearly,
                                          title: "Pro 年度（含试用）",
                                          note: "目标价格：¥70/年（以商店显示为准）")
                Text("正在加载商店价格… 若长期不显示，请在 Scheme → Run → Options 里选择 StoreKit.storekit，并确保产品 ID 匹配。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                Button(action: { Task { await purchaseStore.loadProducts() } }) {
                    Text("刷新价格").font(.caption)
                }
            } else {
                ForEach(purchaseStore.products, id: \.id) { product in
                    selectableProductTile(product)
                }
            }
        }
    }

    private func selectableProductTile(_ product: Product) -> some View {
        Button {
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(title(for: product)).font(.headline)
                    if let offer = product.subscription?.introductoryOffer {
                        Text(introText(from: offer))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(priceNote(for: product))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(selectedProductID == product.id ? 0.18 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedProductID == product.id ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectablePlaceholderTile(id: String, title: String, note: String) -> some View {
        Button { selectedProductID = id } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(note).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(selectedProductID == id ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedProductID == id ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryActionButton: some View {
        Button(action: {
            // Ensure the Button action returns Void (discard Task value)
            _ = Task { @MainActor in
                if selectedProduct() == nil { showHint = true; return }
                await purchaseSelected()
            }
        }) {
            Text(purchaseStore.purchaseInProgress ? "正在购买…" : "继续")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
                .foregroundColor(.white)
        }
        .disabled(purchaseStore.purchaseInProgress)
    }

    private func selectedProduct() -> Product? {
        guard !purchaseStore.products.isEmpty else { return nil }
        if let id = selectedProductID, let p = purchaseStore.products.first(where: { $0.id == id }) { return p }
        return purchaseStore.products.first
    }

    private func purchaseSelected() async {
        guard let product = selectedProduct() else { return }
        await purchaseStore.purchase(product)
    }

    private func title(for product: Product) -> String {
        if product.id == AppEntitlements.ProductID.premiumYearly { return "Pro 年度" }
        if product.id == AppEntitlements.ProductID.premiumMonthly { return "Plus 月度" }
        return product.displayName
    }

    private func introText(from offer: Product.SubscriptionOffer) -> String {
        let p = offer.period
        // Use if-case to avoid exhaustive switch warnings across SDKs
        if case .freeTrial = offer.paymentMode {
            return "含 \(p.value) \(p.unit.localized) 免费试用"
        } else if case .payAsYouGo = offer.paymentMode {
            return "限时优惠"
        } else if case .payUpFront = offer.paymentMode {
            return "限时折扣"
        } else {
            return ""
        }
    }

    private func priceNote(for product: Product) -> String {
        if product.id == AppEntitlements.ProductID.premiumMonthly { return "¥9/月 · 可随时取消订阅" }
        if product.id == AppEntitlements.ProductID.premiumYearly { return "仅¥5.8/月 · 可随时取消订阅" }
        return ""
    }

    private var restorePurchasesButton: some View {
        Button(action: {
            Task {
                await purchaseStore.restore()
            }
        }) {
            Text("恢复购买")
                .font(.footnote)
                .foregroundStyle(.blue)
        }
        .disabled(purchaseStore.purchaseInProgress)
        .padding(.top, 4)
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("隐私政策", destination: URL(string: "https://vbin210327-real.github.io/hulubeici-legal/PrivacyPolicy")!)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("使用条款", destination: URL(string: "https://vbin210327-real.github.io/hulubeici-legal/TermsOfService")!)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var localized: String {
        switch self { case .day: return "天"; case .week: return "周"; case .month: return "月"; case .year: return "年"; @unknown default: return "" }
    }
}
