import SwiftUI

struct RootView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.l10n) private var l10n

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
              Label(l10n.tabHome, systemImage: "house.fill")
            }

          MatchHistoryView()
            .tag(AppModel.Tab.history)
            .tabItem {
              Label(l10n.tabMatches, systemImage: "clock.arrow.circlepath")
            }

          SettingsView()
            .tag(AppModel.Tab.settings)
            .tabItem {
              Label(l10n.tabSettings, systemImage: "gearshape.fill")
            }
        }
        .tint(CourtVoiceTheme.accent)
        .toolbarBackground(CourtVoiceTheme.canvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
      }
    }
    .environment(\.l10n, appModel.l10n)
    .environment(\.locale, appModel.preferences.appLanguage.locale)
    .fullScreenCover(item: $appModel.activeSession) { controller in
      LiveMatchView(controller: controller) {
        Task { await appModel.closeActiveMatch() }
      }
    }
    .alert(
      l10n.somethingWentWrong,
      isPresented: Binding(
        get: { appModel.errorMessage != nil },
        set: { isPresented in
          if isPresented == false { appModel.errorMessage = nil }
        }
      ),
      actions: {
        Button(l10n.ok, role: .cancel) {
          appModel.errorMessage = nil
        }
      },
      message: {
        Text(appModel.errorMessage ?? l10n.unknownError)
      }
    )
  }
}

private struct LaunchLoadingView: View {
  @Environment(\.l10n) private var l10n

  var body: some View {
    ZStack {
      CourtVoiceTheme.courtGradient
        .ignoresSafeArea()

      VStack(spacing: 18) {
        Image(systemName: "tennisball.fill")
          .font(.system(size: 56, weight: .semibold))
          .foregroundStyle(CourtVoiceTheme.tennisYellow)
          .symbolEffect(.pulse)

        Text("CourtVoice")
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(CourtVoiceTheme.onCourt)

        ProgressView()
          .tint(CourtVoiceTheme.onCourt)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(l10n.loadingCourtVoice)
  }
}
