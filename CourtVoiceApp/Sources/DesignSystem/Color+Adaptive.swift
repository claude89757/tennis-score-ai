import SwiftUI
import UIKit

extension Color {
  static func adaptive(light: Color, dark: Color) -> Color {
    Color(
      uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
      }
    )
  }
}
