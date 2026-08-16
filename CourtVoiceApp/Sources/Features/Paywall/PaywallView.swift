import StoreKit
import SwiftUI

struct PaywallView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.l10n) private var l10n

  var body: some View {
    let store = appModel.entitlementStore

    ScrollView {
      VStack(spacing: 22) {
        hero
        benefits

        if store.isPro {
          activeSubscriptionCard
        } else if store.isLoadingProducts {
          ProgressView(l10n.loadingProducts)
            .tint(CourtVoiceTheme.accent)
            .foregroundStyle(CourtVoiceTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .courtVoiceCard()
        } else if store.products.isEmpty {
          unavailableCard
        } else {
          productCards(store.products)
        }

        Button(l10n.restorePurchases) {
          Task { await store.restorePurchases() }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(CourtVoiceTheme.accent)
        .frame(minHeight: CourtVoiceTheme.minimumHitTarget)

        legalFooter
      }
      .padding()
    }
    .courtVoiceCanvas()
    .navigationTitle(l10n.paywallTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(l10n.done) { dismiss() }
          .accessibilityIdentifier("paywall.done")
      }
    }
    .alert(
      "App Store",
      isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if $0 == false { store.errorMessage = nil } }
      )
    ) {
      Button(l10n.ok, role: .cancel) { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? l10n.unknownError)
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

      Text(l10n.paywallHero)
        .font(.system(.largeTitle, design: .rounded, weight: .bold))
        .foregroundStyle(CourtVoiceTheme.textPrimary)
        .multilineTextAlignment(.center)

      Text(l10n.paywallHeroDetail)
        .font(.body)
        .foregroundStyle(CourtVoiceTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
  }

  private var benefits: some View {
    VStack(alignment: .leading, spacing: 15) {
      benefit(l10n.benefitCloud, icon: "waveform.badge.magnifyingglass")
      benefit(l10n.benefitHistory, icon: "clock.arrow.circlepath")
      benefit(l10n.benefitWebBoard, icon: "rectangle.on.rectangle")
      benefit(l10n.benefitFallback, icon: "arrow.triangle.branch")
      benefit(l10n.benefitSync, icon: "icloud.fill")
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
                  .foregroundStyle(CourtVoiceTheme.textPrimary)
                if product.id == EntitlementStore.annualProductID {
                  Text(l10n.bestValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(CourtVoiceTheme.tennisYellow, in: Capsule())
                    .foregroundStyle(CourtVoiceTheme.ink)
                }
              }
              Text(product.description)
                .font(.caption)
                .foregroundStyle(CourtVoiceTheme.textSecondary)
                .multilineTextAlignment(.leading)
            }

            Spacer()

            Text(product.displayPrice)
              .font(.title3.bold())
              .monospacedDigit()
              .foregroundStyle(CourtVoiceTheme.textPrimary)
          }
          .frame(maxWidth: .infinity)
          .padding(18)
          .background(
            product.id == EntitlementStore.annualProductID
              ? CourtVoiceTheme.productHighlight
              : CourtVoiceTheme.productFill,
            in: RoundedRectangle(cornerRadius: 20)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                product.id == EntitlementStore.annualProductID
                  ? CourtVoiceTheme.productHighlightStroke
                  : CourtVoiceTheme.cardStroke,
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
        .foregroundStyle(CourtVoiceTheme.accent)
      Text(l10n.proIsActive)
        .font(.title2.bold())
        .foregroundStyle(CourtVoiceTheme.textPrimary)
      Text(l10n.proVerified)
        .foregroundStyle(CourtVoiceTheme.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .courtVoiceCard()
  }

  private var unavailableCard: some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(CourtVoiceTheme.warning)
      Text(l10n.productsUnavailable)
        .font(.headline)
        .foregroundStyle(CourtVoiceTheme.textPrimary)
      Text(l10n.productsUnavailableDetail)
        .font(.footnote)
        .foregroundStyle(CourtVoiceTheme.textSecondary)
        .multilineTextAlignment(.center)
      Button(l10n.tryAgain) {
        Task { await appModel.entitlementStore.reloadProducts() }
      }
      .foregroundStyle(CourtVoiceTheme.accent)
    }
    .frame(maxWidth: .infinity)
    .courtVoiceCard()
  }

  private var legalFooter: some View {
    VStack(spacing: 10) {
      Text(l10n.subscriptionLegal)
        .font(.caption)
        .foregroundStyle(CourtVoiceTheme.textSecondary)
        .multilineTextAlignment(.center)

      HStack(spacing: 18) {
        Button(l10n.privacy) {
          openURL(URL(string: "https://courtvoice.app/privacy")!)
        }
        Button(l10n.terms) {
          openURL(URL(string: "https://courtvoice.app/terms")!)
        }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(CourtVoiceTheme.accent)
    }
  }

  private func benefit(_ title: String, icon: String) -> some View {
    HStack(spacing: 13) {
      Image(systemName: icon)
        .frame(width: 28)
        .foregroundStyle(CourtVoiceTheme.accent)
      Text(title)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(CourtVoiceTheme.textPrimary)
    }
  }

  private var isPurchasing: Bool {
    if case .purchasing = appModel.entitlementStore.purchaseState { return true }
    return false
  }
}
