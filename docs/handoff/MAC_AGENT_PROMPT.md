# Prompt for the macOS Completion Agent

You are completing the commercial iOS release engineering for `claude89757/tennis-score-ai`.

1. Work from a clean clone of GitHub `main`; no Google Drive or external source bundle is required.
2. Read `HANDOFF.md`, `docs/handoff/LINUX_COMPLETION.md` and `docs/handoff/MAC_AGENT_HANDOFF.md` before editing.
3. Create `agent/macos-commercial-finalization`, then run `./scripts/macos-acceptance.sh` and fix every Xcode/Swift 6 failure until it passes.
4. Preserve deterministic authority: speech/LLM output may propose an intent, but only the validated tennis rules engine may change official score state.
5. Validate onboarding, AI-native live scoring (no manual award/correction), persistence, speech, BYOK, media import, StoreKit, accessibility and adaptive layouts on Simulator.
6. Perform physical-device microphone, interruptions, Bluetooth, outdoor noise and external-display tests.
7. Benchmark the private full-match video without committing it or any production credentials.
8. Capture focused performance and memory evidence, fix app-owned leaks, and repeat the capture.
9. Configure real Apple identifiers, subscriptions, signing and TestFlight only with owner-provided credentials. Never commit secrets or profiles.
10. Commit intentionally, push the branch and open a draft PR containing exact build/test evidence and every remaining limitation. Do not call the app App-Store-ready until all exit criteria in the handoff document pass.
