import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  @State private var page = 0

  private let pages = [
    OnboardingPage(
      icon: "waveform.and.mic",
      title: "Call the score naturally",
      detail:
        "CourtVoice is designed to listen only while a match is active. Manual scoring always remains available."
    ),
    OnboardingPage(
      icon: "checkmark.shield.fill",
      title: "Rules before AI",
      detail:
        "Speech produces a candidate action. A deterministic tennis rules engine is the only component allowed to change the official score."
    ),
    OnboardingPage(
      icon: "rectangle.on.rectangle.angled",
      title: "Readable from the baseline",
      detail:
        "Use the large landscape scoreboard on court, mirror it with AirPlay, or share a match summary afterward."
    ),
  ]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [CourtVoiceTheme.courtGreen, CourtVoiceTheme.ink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 24) {
        HStack {
          Spacer()
          Button("Skip", action: onComplete)
            .foregroundStyle(.white.opacity(0.85))
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

                Text(item.detail)
                  .font(.title3)
                  .foregroundStyle(.white.opacity(0.74))
                  .multilineTextAlignment(.center)
                  .lineSpacing(4)
              }

              Spacer()
            }
            .padding(.horizontal, 28)
            .foregroundStyle(.white)
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
          Text(page == pages.count - 1 ? "Start using CourtVoice" : "Continue")
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
