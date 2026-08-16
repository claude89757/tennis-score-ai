import SwiftUI

@MainActor
enum CourtVoiceTheme {
  static let courtGreen = Color(red: 0.051, green: 0.231, blue: 0.180)
  static let courtGreenLight = Color(red: 0.090, green: 0.310, blue: 0.240)
  static let tennisYellow = Color(red: 0.875, green: 1.000, blue: 0.220)
  static let ivory = Color(red: 0.965, green: 0.961, blue: 0.937)
  static let ink = Color(red: 0.063, green: 0.078, blue: 0.086)
  static let warning = Color(red: 1.000, green: 0.690, blue: 0.125)
  static let courtNight = Color(red: 0.031, green: 0.078, blue: 0.063)
  static let cardNight = Color(red: 0.071, green: 0.141, blue: 0.118)
  static let danger = Color(red: 0.910, green: 0.290, blue: 0.240)

  static let canvas = Color.adaptive(light: ivory, dark: courtNight)
  static let textPrimary = Color.adaptive(light: ink, dark: ivory)
  static let textSecondary = Color.adaptive(
    light: ink.opacity(0.58),
    dark: ivory.opacity(0.70)
  )
  static let textTertiary = Color.adaptive(
    light: ink.opacity(0.40),
    dark: ivory.opacity(0.50)
  )
  static let accent = Color.adaptive(light: courtGreen, dark: tennisYellow)
  static let onAccent = Color.adaptive(light: ivory, dark: ink)
  static let cardFill = Color.adaptive(light: Color.white.opacity(0.94), dark: cardNight)
  static let cardStroke = Color.adaptive(light: ink.opacity(0.08), dark: ivory.opacity(0.12))
  static let productFill = Color.adaptive(light: Color.white.opacity(0.86), dark: cardNight)
  static let productHighlight = Color.adaptive(
    light: courtGreen.opacity(0.12),
    dark: tennisYellow.opacity(0.14)
  )
  static let productHighlightStroke = Color.adaptive(
    light: courtGreen.opacity(0.45),
    dark: tennisYellow.opacity(0.40)
  )

  static let onHero = ivory
  static let onHeroMuted = ivory.opacity(0.78)
  static let onCourt = ivory
  static let onCourtMuted = ivory.opacity(0.74)
  static let onCourtFaint = ivory.opacity(0.52)
  static let onCourtSubtle = ivory.opacity(0.22)
  static let courtPanel = Color.white.opacity(0.10)
  static let courtPanelStroke = Color.white.opacity(0.12)

  static let cardCornerRadius: CGFloat = 24
  static let controlCornerRadius: CGFloat = 16
  static let minimumHitTarget: CGFloat = 48

  static var heroGradient: LinearGradient {
    LinearGradient(
      colors: [courtGreenLight, courtGreen],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static var courtGradient: LinearGradient {
    LinearGradient(
      colors: [courtGreen, ink],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

extension View {
  func courtVoiceCard() -> some View {
    self
      .padding(20)
      .background(
        CourtVoiceTheme.cardFill,
        in: RoundedRectangle(cornerRadius: CourtVoiceTheme.cardCornerRadius)
      )
      .overlay {
        RoundedRectangle(cornerRadius: CourtVoiceTheme.cardCornerRadius)
          .stroke(CourtVoiceTheme.cardStroke, lineWidth: 1)
      }
  }

  func courtVoiceCanvas() -> some View {
    self
      .background(CourtVoiceTheme.canvas.ignoresSafeArea())
  }

  func courtVoiceListChrome() -> some View {
    self
      .scrollContentBackground(.hidden)
      .background(CourtVoiceTheme.canvas.ignoresSafeArea())
      .tint(CourtVoiceTheme.accent)
  }
}
