# Mac Agent Handoff — CourtVoice

## Mission

Continue from the merged `main` branch, make the generated Xcode project compile cleanly under Swift 6, validate the primary product flows on Simulator and physical devices, and prepare a reviewable follow-up pull request. Do not redesign the product or bypass deterministic scoring authority.

No Google Drive or external source archive is part of this workflow. GitHub `main` is the authoritative source.

## 1. Prepare a clean macOS workspace

```bash
git clone https://github.com/claude89757/tennis-score-ai.git
cd tennis-score-ai
git switch main
git pull --ff-only
brew install xcodegen xcbeautify
./scripts/macos-acceptance.sh
```

Create a dedicated branch before making fixes:

```bash
git switch -c agent/macos-commercial-finalization
```

## 2. First compiler focus

Inspect these areas first because Linux cannot type-check Apple SDK calls:

- Swift 6 actor isolation and `Sendable` boundaries around AVFoundation, Speech, URLSession WebSockets, SwiftData and StoreKit.
- Availability and deprecation diagnostics for the installed iOS SDK.
- Audio-engine tap callbacks, conversion buffers and interruption handling.
- StoreKit transaction verification and transaction-update lifecycle.
- Observation ownership, environment injection and navigation state.
- XcodeGen target paths, resources, entitlements and test target membership.

Make the smallest compile-correct changes. Do not disable strict concurrency globally.

## 3. Simulator acceptance

Capture logs or screenshots for:

1. First launch and onboarding.
2. Create a match and score manually through deuce/advantage, undo, correction and finish.
3. Force-quit and relaunch during a match; verify persisted history.
4. Confirm microphone and Speech permissions are requested only when listening starts.
5. Verify partial/final transcript handling does not duplicate score events.
6. Verify model/provider failure never disables manual scoring.
7. Save and remove BYOK credentials without exposing them in UI or logs.
8. Import a short local media file and inspect transcript-to-score handling.
9. Run local StoreKit monthly/annual purchase, trial, restore, pending and revocation scenarios.
10. Check portrait, landscape, Dynamic Type, VoiceOver, Reduce Motion, iPhone and iPad layouts.

## 4. Physical-device and court gates

On a real iPhone or iPad:

- Run at least one long match session.
- Test indoor, outdoor, wind and adjacent-court noise.
- Test Bluetooth connect/disconnect, calls, Siri/audio interruption, background/foreground and network loss.
- Verify the listening state is always visible and raw microphone audio is not persisted by default.
- Validate external display or AirPlay connect/disconnect and large-score readability.
- Record battery, thermal and memory behavior.

## 5. Model benchmark

Use the owner's private full-match video without committing it. Compare the supported providers on:

- score-event precision and recall;
- incorrect automatic score-update rate;
- timestamp quality;
- median and P95 latency;
- actual billed speech minutes and cost;
- mixed Chinese/English behavior;
- noisy outdoor behavior;
- fallback and recovery behavior.

The release target is trustworthy automatic acceptance, not the highest raw transcript recall. Low-confidence or conflicting input must request confirmation.

## 6. StoreKit and release configuration

Before TestFlight:

- Replace placeholder Team ID, bundle identifier, support/privacy/terms URLs and production backend URL.
- Create the monthly and annual products plus the intended introductory trial in App Store Connect.
- Test purchase, renewal, cancellation, grace period, billing retry, refund, revocation and restore.
- Inspect the Release archive's embedded entitlements and privacy manifest.
- Complete App Privacy answers and Review Notes from actual behavior.
- Keep undeveloped capabilities and background modes disabled.

## 7. Performance and memory evidence

Capture focused Instruments evidence for:

- cold launch to interactive home;
- start listening to first partial transcript;
- long live-scoring session;
- media import to completed analysis;
- closing a match and returning to history.

Use ETTrace/Time Profiler and memory graph/leaks. Fix app-owned retain cycles and repeat the capture.

## Exit criteria

The Mac phase is complete only when one commit has:

- portable and iOS tests passing;
- Debug and Release Simulator builds passing with strict concurrency;
- primary flows visually inspected;
- physical-device audio smoke evidence;
- StoreKit local and Sandbox evidence;
- no unresolved app-owned leak in tested close flows;
- signing and TestFlight upload completed or a precise credential-only blocker documented;
- a draft PR with evidence paths and remaining real-court limitations.
