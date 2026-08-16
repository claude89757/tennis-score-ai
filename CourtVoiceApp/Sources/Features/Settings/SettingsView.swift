import Foundation
import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var appModel

  var body: some View {
    NavigationStack {
      List {
        Section("Subscription") {
          NavigationLink {
            PaywallView()
          } label: {
            Label(
              appModel.entitlementStore.isPro
                ? "CourtVoice Pro active" : "Upgrade to CourtVoice Pro",
              systemImage: appModel.entitlementStore.isPro ? "checkmark.seal.fill" : "sparkles"
            )
          }
          LabeledContent(
            "Status",
            value: appModel.entitlementStore.isPro ? "Active" : "Free"
          )
        }

        Section("Scoring") {
          NavigationLink {
            ModelSettingsView()
          } label: {
            Label("Speech & AI models", systemImage: "waveform.and.mic")
          }

          LabeledContent(
            "Default mode",
            value: appModel.preferences.speechConfiguration.provider.title
          )
          LabeledContent(
            "Language",
            value: appModel.preferences.speechConfiguration.localeIdentifier
          )
        }

        Section("Privacy") {
          Label("Raw live audio is not saved", systemImage: "waveform.slash")
          Label("Match history stays on device", systemImage: "iphone")
          Label(
            "BYOK credentials stay in Keychain",
            systemImage: "key.fill"
          )
        }

        Section("About") {
          LabeledContent("Version", value: appVersion)
          Link(destination: URL(string: "https://github.com/claude89757/tennis-score-ai")!) {
            Label("Source repository", systemImage: "chevron.left.forwardslash.chevron.right")
          }
        }
      }
      .navigationTitle("Settings")
    }
  }

  private var appVersion: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }
}
