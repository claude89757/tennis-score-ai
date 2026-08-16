# Linux Engineering Completion Boundary

## Included in the merged repository

- Deterministic tennis scoring with event history, correction, undo/redo, deuce/advantage, No-Ad and tiebreak foundations.
- Conservative Chinese and English score-intent parsing. Speech or LLM output proposes an intent; only the deterministic rules engine may mutate official score state.
- SwiftUI onboarding, home, match setup, adaptive live scoring, correction, history, settings and subscription surfaces.
- Offline-first local match persistence and resume behavior.
- Apple Speech integration foundations for live recognition.
- OpenAI-compatible and Deepgram BYOK transcription adapters.
- Device-only Keychain storage abstractions for provider credentials.
- Imported video/audio analysis flow and rules-gated score replay.
- StoreKit 2 products, entitlement state, purchase/restore flow and local StoreKit configuration foundations.
- Swift package tests for the portable domain and intent modules.
- XcodeGen project definition, privacy manifest, entitlements and app resources.

## What Linux can validate

- Portable Swift package compilation and tests.
- Source parsing and repository structure.
- JSON, plist, StoreKit configuration and asset-catalog metadata.
- Documentation integrity and absence of committed production secrets.

Linux does not contain the Apple SDK. Parser success is not a substitute for Xcode type checking, linking, Simulator execution or device evidence.

## Deliberately deferred to macOS and devices

- XcodeGen generation against the installed Xcode version.
- Swift 6 strict-concurrency type checking at Apple framework boundaries.
- Simulator build, unit tests, UI smoke tests and visual inspection.
- Real microphone, Speech language assets, Bluetooth and audio-interruption behavior.
- Outdoor wind and adjacent-court recognition accuracy.
- External-display/AirPlay behavior.
- StoreKit Configuration and Sandbox purchase, renewal, cancellation, refund and restore cases.
- Code signing, archive, TestFlight and App Store Connect configuration.
- ETTrace, memory graph and long-session battery/thermal evidence.
- Benchmarking with the owner's private complete tennis video and real provider credentials.

## Security boundary

Never commit API keys, certificates, provisioning profiles, App Store Connect private keys, signed StoreKit payloads, private match videos or raw user audio. Production application-owned provider credentials belong on a backend, not in the iOS bundle.
