import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  @Environment(\.l10n) private var l10n
  @State private var page = 0

  var body: some View {
    let pages = [
      OnboardingPage(
        icon: "waveform.and.mic",
        title: l10n.onboardingTitle1,
        detail: l10n.onboardingDetail1
      ),
      OnboardingPage(
        icon: "checkmark.shield.fill",
        title: l10n.onboardingTitle2,
        detail: l10n.onboardingDetail2
      ),
      OnboardingPage(
        icon: "rectangle.on.rectangle.angled",
        title: l10n.onboardingTitle3,
        detail: l10n.onboardingDetail3
      ),
    ]

    ZStack {
      CourtVoiceTheme.courtGradient
        .ignoresSafeArea()

      VStack(spacing: 24) {
        HStack {
          Spacer()
          Button(l10n.skip, action: onComplete)
            .foregroundStyle(CourtVoiceTheme.onCourtMuted)
            .padding(.horizontal, 8)
            .frame(minHeight: CourtVoiceTheme.minimumHitTarget)
            .accessibilityIdentifier("onboarding.skip")
        }

        TabView(selection: $page) {
          ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
            VStack(spacing: 28) {
              Spacer()

              Image(systemName: item.icon)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(CourtVoiceTheme.tennisYellow)
                .symbolRenderingMode(.hierarchical)

              VStack(spacing: 14) {
                Text(item.title)
                  .font(.system(.largeTitle, design: .rounded, weight: .bold))
                  .multilineTextAlignment(.center)
                  .accessibilityIdentifier("onboarding.title")

                Text(item.detail)
                  .font(.title3)
                  .foregroundStyle(CourtVoiceTheme.onCourtMuted)
                  .multilineTextAlignment(.center)
                  .lineSpacing(4)
              }

              Spacer()
            }
            .padding(.horizontal, 28)
            .foregroundStyle(CourtVoiceTheme.onCourt)
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))

        Button {
          if page == pages.count - 1 {
            onComplete()
          } else {
            withAnimation(.snappy) { page += 1 }
          }
        } label: {
          Text(page == pages.count - 1 ? l10n.onboardingStart : l10n.continueAction)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(CourtVoiceTheme.tennisYellow)
        .foregroundStyle(CourtVoiceTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: CourtVoiceTheme.controlCornerRadius))
        .accessibilityIdentifier("onboarding.continue")
      }
      .padding()
    }
  }
}

private struct OnboardingPage {
  let icon: String
  let title: String
  let detail: String
}
