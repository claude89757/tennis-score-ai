import SwiftUI

struct SettingsView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Scoring") {
          NavigationLink {
            ModelSettingsPlaceholderView()
          } label: {
            Label("Speech & AI models", systemImage: "waveform.and.mic")
          }

          LabeledContent("Default mode", value: "Manual + local")
        }

        Section("Privacy") {
          Label("Raw live audio is not saved", systemImage: "waveform.slash")
          Label("Match history stays on device", systemImage: "iphone")
          Label(
            "Cloud processing requires an explicit provider", systemImage: "icloud.and.arrow.up")
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

private struct ModelSettingsPlaceholderView: View {
  var body: some View {
    List {
      Section {
        Label("Apple on-device speech", systemImage: "apple.logo")
        Label("CourtVoice hosted cloud", systemImage: "cloud.fill")
        Label("Bring your own API key", systemImage: "key.fill")
      } header: {
        Text("Provider architecture")
      } footer: {
        Text(
          "Provider switching and secure Keychain credential management are integrated in the next delivery stage. Manual scoring remains fully functional without a provider."
        )
      }
    }
    .navigationTitle("Speech & AI")
  }
}
