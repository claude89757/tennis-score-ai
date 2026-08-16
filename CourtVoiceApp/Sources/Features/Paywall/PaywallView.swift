import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  var body: some View {
    let store = appModel.entitlementStore

    ScrollView {
      VStack(spacing: 22) {
        hero
        benefits

        if store.isPro {
          activeSubscriptionCard
        } else if store.isLoadingProducts {
          ProgressView("Loading App Store products…")
            .frame(maxWidth: .infinity)
            .courtVoiceCard()
        } else if store.products.isEmpty {
          unavailableCard
        } else {
          productCards(store.products)
        }

        Button("Restore purchases") {
          Task { await store.restorePurchases() }
        }
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: CourtVoiceTheme.minimumHitTarget)

        legalFooter
      }
      .padding()
    }
    .background(CourtVoiceTheme.ivory.ignoresSafeArea())
    .navigationTitle("CourtVoice Pro")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Done") { dismiss() }
      }
    }
    .alert(
      "App Store",
      isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if $0 == false { store.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? "Unknown error")
    }
  }

  private var hero: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(CourtVoiceTheme.tennisYellow)
          .frame(width: 94, height: 94)
        Image(systemName: "sparkles")
          .font(.system(size: 40, weight: .bold))
          .foregroundStyle(CourtVoiceTheme.ink)
      }

      Text("Every court can feel match-ready")
        .font(.system(.largeTitle, design: .rounded, weight: .bold))
        .multilineTextAlignment(.center)

      Text(
        "Pro adds managed cloud usage, complete exports, unlimited history, live web scoreboards and cross-device services. Starting a match and watching the live board remain available without Pro."
      )
      .font(.body)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
  }

  private var benefits: some View {
    VStack(alignment: .leading, spacing: 15) {
      benefit("Managed cloud recognition allowance", icon: "waveform.badge.magnifyingglass")
      benefit("Unlimited match history and audit exports", icon: "clock.arrow.circlepath")
      benefit("Read-only live web scoreboard links", icon: "rectangle.on.rectangle")
      benefit("Automatic provider fallback", icon: "arrow.triangle.branch")
      benefit("Future cross-device synchronization", icon: "icloud.fill")
    }
    .courtVoiceCard()
  }

  private func productCards(_ products: [Product]) -> some View {
    VStack(spacing: 12) {
      ForEach(products) { product in
        Button {
          Task {
            if await appModel.entitlementStore.purchase(product) {
              dismiss()
            }
          }
        } label: {
          HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
              HStack(spacing: 8) {
                Text(product.displayName)
                  .font(.headline)
                if product.id == EntitlementStore.annualProductID {
                  Text("BEST VALUE")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(CourtVoiceTheme.tennisYellow, in: Capsule())
                    .foregroundStyle(CourtVoiceTheme.ink)
                }
              }
              Text(product.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            }

            Spacer()

            Text(product.displayPrice)
              .font(.title3.bold())
              .monospacedDigit()
          }
          .frame(maxWidth: .infinity)
          .padding(18)
          .background(
            product.id == EntitlementStore.annualProductID
              ? CourtVoiceTheme.courtGreen.opacity(0.12)
              : Color.white.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 20)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                product.id == EntitlementStore.annualProductID
                  ? CourtVoiceTheme.courtGreen.opacity(0.45)
                  : Color.black.opacity(0.08),
                lineWidth: 1
              )
          }
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
      }
    }
  }

  private var activeSubscriptionCard: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .font(.largeTitle)
        .foregroundStyle(CourtVoiceTheme.courtGreen)
      Text("CourtVoice Pro is active")
        .font(.title2.bold())
      Text("Your entitlement was verified from StoreKit on this device.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .courtVoiceCard()
  }

  private var unavailableCard: some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(CourtVoiceTheme.warning)
      Text("Products are unavailable")
        .font(.headline)
      Text(
        "Use the checked-in StoreKit test configuration in Xcode, or configure matching product identifiers in App Store Connect."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      Button("Try again") {
        Task { await appModel.entitlementStore.reloadProducts() }
      }
    }
    .frame(maxWidth: .infinity)
    .courtVoiceCard()
  }

  private var legalFooter: some View {
    VStack(spacing: 10) {
      Text(
        "Subscriptions renew automatically unless cancelled. Billing, eligibility for introductory offers and localized prices are controlled by the App Store."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)

      HStack(spacing: 18) {
        Button("Privacy") {
          openURL(URL(string: "https://courtvoice.app/privacy")!)
        }
        Button("Terms") {
          openURL(URL(string: "https://courtvoice.app/terms")!)
        }
      }
      .font(.caption.weight(.semibold))
    }
  }

  private func benefit(_ title: String, icon: String) -> some View {
    HStack(spacing: 13) {
      Image(systemName: icon)
        .frame(width: 28)
        .foregroundStyle(CourtVoiceTheme.courtGreen)
      Text(title)
        .font(.subheadline.weight(.medium))
    }
  }

  private var isPurchasing: Bool {
    if case .purchasing = appModel.entitlementStore.purchaseState { return true }
    return false
  }
}
