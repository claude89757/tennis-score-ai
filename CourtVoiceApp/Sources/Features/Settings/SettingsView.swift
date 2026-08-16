import Foundation
import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var appModel
  @Environment(\.l10n) private var l10n

  var body: some View {
    NavigationStack {
      List {
        Section(l10n.appLanguage) {
          Picker(l10n.appLanguage, selection: languageBinding) {
            ForEach(AppLanguage.allCases) { language in
              Text(language.displayName).tag(language)
            }
          }
          .pickerStyle(.segmented)
          .listRowBackground(CourtVoiceTheme.cardFill)
          .accessibilityIdentifier("settings.appLanguage")
        }

        Section(l10n.subscription) {
          NavigationLink {
            PaywallView()
          } label: {
            Label(
              appModel.entitlementStore.isPro ? l10n.proActive : l10n.upgradeToPro,
              systemImage: appModel.entitlementStore.isPro ? "checkmark.seal.fill" : "sparkles"
            )
          }
          .accessibilityIdentifier("settings.paywall")
          .listRowBackground(CourtVoiceTheme.cardFill)

          LabeledContent(
            l10n.status,
            value: appModel.entitlementStore.isPro ? l10n.active : l10n.free
          )
          .listRowBackground(CourtVoiceTheme.cardFill)
        }

        Section(l10n.scoring) {
          NavigationLink {
            ModelSettingsView()
          } label: {
            Label(l10n.speechAndAIModels, systemImage: "waveform.and.mic")
          }
          .accessibilityIdentifier("settings.speechModels")
          .listRowBackground(CourtVoiceTheme.cardFill)

          LabeledContent(
            l10n.defaultMode,
            value: l10n.providerTitle(appModel.preferences.speechConfiguration.provider)
          )
          .listRowBackground(CourtVoiceTheme.cardFill)
          LabeledContent(
            l10n.recognitionLanguageLabel,
            value: speechLanguageLabel
          )
          .listRowBackground(CourtVoiceTheme.cardFill)
        }

        Section(l10n.privacy) {
          Label(l10n.privacyAudio, systemImage: "waveform.slash")
            .listRowBackground(CourtVoiceTheme.cardFill)
          Label(l10n.privacyHistory, systemImage: "iphone")
            .listRowBackground(CourtVoiceTheme.cardFill)
          Label(l10n.privacyKeys, systemImage: "key.fill")
            .listRowBackground(CourtVoiceTheme.cardFill)
        }

        Section(l10n.about) {
          LabeledContent(l10n.version, value: appVersion)
            .listRowBackground(CourtVoiceTheme.cardFill)
          Link(destination: URL(string: "https://github.com/claude89757/tennis-score-ai")!) {
            Label(l10n.sourceRepository, systemImage: "chevron.left.forwardslash.chevron.right")
          }
          .listRowBackground(CourtVoiceTheme.cardFill)
        }
      }
      .listStyle(.insetGrouped)
      .courtVoiceListChrome()
      .foregroundStyle(CourtVoiceTheme.textPrimary)
      .navigationTitle(l10n.settings)
      .toolbarBackground(CourtVoiceTheme.canvas, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
    }
  }

  private var languageBinding: Binding<AppLanguage> {
    Binding(
      get: { appModel.preferences.appLanguage },
      set: { language in
        Task { await appModel.updateAppLanguage(language) }
      }
    )
  }

  private var speechLanguageLabel: String {
    switch appModel.preferences.speechConfiguration.localeIdentifier {
    case "zh-CN": "简体中文"
    case "en-US": "English (US)"
    case "ko-KR": "한국어"
    default: appModel.preferences.speechConfiguration.localeIdentifier
    }
  }

  private var appVersion: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
  }
}
