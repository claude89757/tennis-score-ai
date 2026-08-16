import SwiftUI

struct RootView: View {
  @Environment(AppModel.self) private var appModel

  var body: some View {
    @Bindable var appModel = appModel

    Group {
      if appModel.isBootstrapping {
        LaunchLoadingView()
      } else if appModel.hasCompletedOnboarding == false {
        OnboardingView {
          Task { await appModel.completeOnboarding() }
        }
      } else {
        TabView(selection: $appModel.selectedTab) {
          HomeView()
            .tag(AppModel.Tab.home)
            .tabItem {
              Label("Home", systemImage: "house.fill")
            }

          MatchHistoryView()
            .tag(AppModel.Tab.history)
            .tabItem {
              Label("Matches", systemImage: "clock.arrow.circlepath")
            }

          SettingsView()
            .tag(AppModel.Tab.settings)
            .tabItem {
              Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(CourtVoiceTheme.tennisYellow)
      }
    }
    .fullScreenCover(item: $appModel.activeSession) { controller in
      LiveMatchView(controller: controller) {
        Task { await appModel.closeActiveMatch() }
      }
    }
    .alert(
      "Something went wrong",
      isPresented: Binding(
        get: { appModel.errorMessage != nil },
        set: { isPresented in
          if isPresented == false { appModel.errorMessage = nil }
        }
      ),
      actions: {
        Button("OK", role: .cancel) {
          appModel.errorMessage = nil
        }
      },
      message: {
        Text(appModel.errorMessage ?? "Unknown error")
      }
    )
  }
}

private struct LaunchLoadingView: View {
  var body: some View {
    ZStack {
      CourtVoiceTheme.courtGreen
        .ignoresSafeArea()

      VStack(spacing: 18) {
        Image(systemName: "tennisball.fill")
          .font(.system(size: 56, weight: .semibold))
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
          .symbolEffect(.pulse)

        Text("CourtVoice")
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(.white)

        ProgressView()
          .tint(.white)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading CourtVoice")
  }
}
