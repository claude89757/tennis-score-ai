# Mac acceptance evidence

Branch: `agent/macos-commercial-finalization`  
Xcode: 26.1 (17B55)  
Swift: 6.2.1  
Simulator: iPhone 17 Pro, iOS 26.1  
Physical device: iPhone 17 Pro Max (`iPhone18,2`), iOS 27.0 Beta (`24A5370h`)

This is an engineering integration milestone. It is **not** App Store release approval.

## Automated gates

| Gate | Result | Notes |
| --- | --- | --- |
| `swift test` portable packages | Passed | 13 tests (CourtVoiceCore + CourtVoiceAI) |
| `./scripts/macos-acceptance.sh` | Passed after Xcode/Swift 6 fixes | Debug tests + Release Simulator build |
| `CourtVoiceAppTests` | Passed | Voice persistence, resume, low-confidence hold, DeepSeek proposal/no double-count, StoreKit product IDs |
| `CourtVoiceAppUITests` (Simulator) | Passed | Onboarding, live agent board, relaunch, settings, paywall, media surface |
| `CourtVoiceAppUITests` (device) | Passed after AI-native change | Voice permission / listen / Home-button resume; no manual award controls |

Latest acceptance artifacts live under `build/mac-acceptance-*` and `build/device-smoke` (gitignored). Re-run:

```bash
./scripts/macos-acceptance.sh
./scripts/simulator-smoke.sh
./scripts/device-smoke.sh
```

## Simulator visual inspection

Screenshots: [docs/handoff/evidence/simulator](evidence/simulator)

1. First launch / onboarding — `01-onboarding.png`
2. Home after skip — `02-home.png`
3. Create match — `03-match-setup.png`
4. Live match scoreboard + voice agent — `04-live-match.png`
5. Transcript / DeepSeek thinking panel — `05-live-agent.png`
6. Landscape live match — `06-live-landscape.png`
7. Force-quit and relaunch with persisted Continue card — `07-home-after-relaunch.png`
8. Match history — `08-match-history.png`
9. Settings — `09-settings.png`
10. Local StoreKit paywall surface — `10-paywall.png`
11. BYOK / speech settings (SecureField, no key echo) — `11-model-settings.png`
12. Media import surface — `12-media-analysis.png`
13. Home remains usable after closing media import — `13-home-after-media.png`

Verified in UI tests, not only screenshots:

- Live match has no award / undo / correct-score controls.
- Repeated legal transcripts do not double-count a point.
- Low-confidence speech does not change the official score.
- Hypothetical Chinese language does not mutate score.
- Closing and relaunching restores the in-progress match.

## Physical-device smoke

Screenshots: [docs/handoff/evidence/device](evidence/device)

Device: iPhone 17 Pro Max, iOS 27.0 Beta, Developer Mode on, wired, paired.  
Local signing used `Apple Development: thanksqqq@live.com` / team `A2YR8HBQKY`. That team ID is **not** written into `project.yml`.

`01`–`13` were captured on-device by the same UI tests as Simulator. Additional device-only frames:

14. Live match before listen — `14-device-before-listen.png`
15. After Start voice scoring: **Listening · Apple on-device**, orange Dynamic Island microphone indicator, Stop listening visible — `15-device-after-listen.png`
16. Agent controls remain after listen (no manual award buttons) — `16-device-agent-after-voice.png`
17. Home button then foreground: match, scoreboard, and listening state still visible — `17-device-after-background.png`

Verified on the physical device, not only screenshots:

- Install and launch of `com.claude89757.courtvoice` succeed.
- Microphone / Speech permission is requested only when listening starts.
- Listening state stays on screen; raw microphone audio is not persisted by this path.
- The live board shows transcript and model-thinking regions instead of manual scoring.
- Background via the Home button and returning to the app keeps the agent controls available.

Xcode 26.1 still logs `Error locating DeviceSupport directory` against this iOS 27.0 beta. UI tests ran anyway; this is not a substitute for a matching Xcode beta if later Instruments or debugger features fail.

## Compile fixes included in this branch

- Privacy and usage-description keys now live in `project.yml` `info.properties`. Bare `xcodegen generate` had rewritten `Info.plist` and dropped `NSMicrophoneUsageDescription`, which made the test host abort when any code path touched the microphone.
- XcodeGen `TEST_HOST` now points at `CourtVoice.app` instead of `CourtVoiceApp.app`.
- App module name is `CourtVoiceApp` so `@testable import` resolves.
- OpenAI multipart language string no longer uses an invalid escaped literal.
- SwiftUI `Section` header/footer uses the iOS 26 initializer.
- `@Observable` `isolated deinit` crashed on release (`libmalloc` / `swift_task_deinitOnExecutor`). Task cancellation now goes through `CancellableTaskHandle`.
- AVAudioConverter callback uses `nonisolated(unsafe)` only for the documented synchronous convert path.
- Live-match toolbar no longer lets the status text collapse into a single-character column.
- `AppleSpeechProvider` installed its AVAudioEngine tap from a `@MainActor` method. Swift 6 isolated that tap closure; the realtime audio thread then hit `swift_task_isCurrentExecutor` / `EXC_BREAKPOINT`. The tap now appends buffers through a nonisolated installer and an `@unchecked Sendable` request slot.

## Remaining real-device and release blockers

These are credential, hardware, or owner-private inputs. They are not implied by Simulator or short-device smoke green.

- Physical iPhone/iPad: long match, outdoor wind, adjacent-court noise, Bluetooth, calls/Siri interruption, network loss.
- External display / AirPlay readability.
- Simulator unit tests must not call `startListening()`; doing so crashes the test host because the clone process lacks the usage-description path used by the app target during some test clones.
- StoreKit Sandbox: purchase, renewal, cancellation, grace period, billing retry, refund, revocation, restore. Local `CourtVoice.storekit` is present, but `StoreKitTest` cannot be imported under this SDK while warnings-as-errors is on (`SKPaymentTransactionState` deprecated in the framework header).
- Owner-private full-match video benchmark (precision/recall, incorrect auto-update rate, latency, billed minutes, mixed language, outdoor noise). Do not commit the video or provider keys.
- Instruments / ETTrace / memory graph / long-session battery and thermal evidence.
- Replace placeholder Team ID, support/privacy/terms URLs (`https://courtvoice.app/...`), and any production backend URL.
- Create matching monthly/annual products and the 7-day annual trial in App Store Connect.
- Signing, Release archive entitlements inspection, TestFlight upload.
- Review Privacy Manifest accessed-API answers against the final binary.
- `UIRequiredDeviceCapabilities` includes `microphone`; confirm this matches the intended device set before App Store submission.

## Security

No API keys, certificates, provisioning profiles, App Store Connect keys, signed StoreKit payloads, private match videos, or raw user audio were added to the repository.
