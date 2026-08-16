import SwiftUI

@MainActor
enum CourtVoiceTheme {
  static let courtGreen = Color(red: 0.051, green: 0.231, blue: 0.180)
  static let courtGreenLight = Color(red: 0.090, green: 0.310, blue: 0.240)
  static let tennisYellow = Color(red: 0.875, green: 1.000, blue: 0.220)
  static let ivory = Color(red: 0.965, green: 0.961, blue: 0.937)
  static let ink = Color(red: 0.063, green: 0.078, blue: 0.086)
  static let warning = Color(red: 1.000, green: 0.690, blue: 0.125)

  static let cardCornerRadius: CGFloat = 24
  static let controlCornerRadius: CGFloat = 16
  static let minimumHitTarget: CGFloat = 48
}

extension View {
  func courtVoiceCard() -> some View {
    self
      .padding(20)
      .background(
        .thinMaterial, in: RoundedRectangle(cornerRadius: CourtVoiceTheme.cardCornerRadius))
  }
}
