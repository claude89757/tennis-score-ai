# Mac acceptance evidence

Branch: `agent/macos-commercial-finalization`  
Xcode: 26.1 (17B55)  
Swift: 6.2.1  
Simulator: iPhone 17 Pro, iOS 26.1

This is an engineering integration milestone. It is **not** App Store release approval.

## Automated gates

| Gate | Result | Notes |
| --- | --- | --- |
| `swift test` portable packages | Passed | 13 tests (CourtVoiceCore + CourtVoiceAI) |
| `./scripts/macos-acceptance.sh` | Passed after Xcode/Swift 6 fixes | Debug tests + Release Simulator build |
| `CourtVoiceAppTests` | Passed | Persistence, correction, resume, speech confirmation, StoreKit product IDs |
| `CourtVoiceAppUITests` | Passed | Onboarding, manual scoring, relaunch, settings, paywall, media surface |

Latest acceptance artifacts live under `build/mac-acceptance-*` (gitignored). Re-run:

```bash
./scripts/macos-acceptance.sh
./scripts/simulator-smoke.sh
```

## Simulator visual inspection

Screenshots: [docs/handoff/evidence/simulator](evidence/simulator)

1. First launch / onboarding — `01-onboarding.png`
2. Home after skip — `02-home.png`
3. Create match — `03-match-setup.png`
4. Manual live scoring — `04-live-match.png`
5. Deuce / undo / correction sheet — `05-score-correction.png`
6. Landscape live match — `06-live-landscape.png`
7. Force-quit and relaunch with persisted Continue card — `07-home-after-relaunch.png`
8. Match history — `08-match-history.png`
9. Settings — `09-settings.png`
10. Local StoreKit paywall surface — `10-paywall.png`
11. BYOK / speech settings (SecureField, no key echo) — `11-model-settings.png`
12. Media import surface — `12-media-analysis.png`
13. Home remains usable after closing media import — `13-home-after-media.png`

Verified in UI tests, not only screenshots:

- Manual scoring still works if voice is never started.
- Repeated legal transcripts do not double-count a point.
- Low-confidence speech requires confirmation before the rules engine mutates score.
- Hypothetical Chinese language does not mutate score.
- Closing and relaunching restores the in-progress match.

## Compile fixes included in this branch

- Privacy and usage-description keys now live in `project.yml` `info.properties`. Bare `xcodegen generate` had rewritten `Info.plist` and dropped `NSMicrophoneUsageDescription`, which made the test host abort when any code path touched the microphone.
- XcodeGen `TEST_HOST` now points at `CourtVoice.app` instead of `CourtVoiceApp.app`.
- App module name is `CourtVoiceApp` so `@testable import` resolves.
- OpenAI multipart language string no longer uses an invalid escaped literal.
- SwiftUI `Section` header/footer uses the iOS 26 initializer.
- `@Observable` `isolated deinit` crashed on release (`libmalloc` / `swift_task_deinitOnExecutor`). Task cancellation now goes through `CancellableTaskHandle`.
- AVAudioConverter callback uses `nonisolated(unsafe)` only for the documented synchronous convert path.
- Live-match toolbar no longer lets the status text collapse into a single-character column.

## Remaining real-device and release blockers

These are credential, hardware, or owner-private inputs. They are not implied by Simulator green.

- Physical iPhone/iPad: long match, outdoor wind, adjacent-court noise, Bluetooth, calls/Siri interruption, background/foreground, network loss.
- External display / AirPlay readability.
- Microphone and Speech permission timing on a real device. Simulator unit tests must not call `startListening()`; doing so crashes the test host because the clone process lacks the usage-description path used by the app target during some test clones.
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
