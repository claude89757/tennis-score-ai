# CourtVoice Engineering Handoff

This repository is the single source of truth for the CourtVoice iOS project. No external Drive package is required.

The merged Linux phase provides a substantial iOS product foundation, portable scoring and intent modules, speech-provider adapters, media-import analysis, local persistence, Keychain-backed BYOK settings, and StoreKit 2 subscription foundations. It is an engineering integration milestone, not App Store release approval.

## Start here on macOS

1. Read [Linux completion boundary](docs/handoff/LINUX_COMPLETION.md).
2. Read [Mac completion instructions](docs/handoff/MAC_AGENT_HANDOFF.md).
3. Give the Mac development agent [the ready-to-use prompt](docs/handoff/MAC_AGENT_PROMPT.md).
4. From a clean clone of `main`, run:

```bash
./scripts/macos-acceptance.sh
```

Do not describe CourtVoice as App-Store-ready until Xcode compilation, Simulator tests, physical-device audio, StoreKit Sandbox, signing, TestFlight, performance/leak checks, and the private full-match benchmark all pass.
