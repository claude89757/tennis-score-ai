import SwiftUI

@main
struct CourtVoiceApp: App {
  @State private var appModel = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appModel)
        .task {
          await appModel.prepareLaunchConfiguration()
          await appModel.bootstrap()
        }
    }
  }
}
