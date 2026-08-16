import SwiftUI

@main
struct CourtVoiceApp: App {
  @State private var appModel = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appModel)
        .environment(\.l10n, appModel.l10n)
        .environment(\.locale, appModel.preferences.appLanguage.locale)
        .tint(CourtVoiceTheme.accent)
        .task {
          await appModel.prepareLaunchConfiguration()
          await appModel.bootstrap()
        }
    }
  }
}
