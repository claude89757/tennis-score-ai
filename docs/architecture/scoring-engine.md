# Deterministic scoring architecture

CourtVoice treats speech and language models as **untrusted sensors**. They can propose a candidate intent, but they never directly mutate the official match state.

## Trust boundary

```text
microphone / imported media
        ↓
transcription provider
        ↓
deterministic parser or structured LLM output
        ↓
IntentCandidate
        ↓
ScoreIntentResolver
        ↓
MatchEventKind
        ↓
MatchTimeline + MatchReducer
        ↓
MatchState
```

The `MatchTimeline` is append-only. Undo is represented by `eventRevoked(eventID:)`, preserving the original event and the revocation for audits, dispute review, exports and model evaluation.

## Core invariants

- A completed match cannot accept new points.
- A point event is accepted only while the match is in progress.
- Idempotency keys prevent a streaming transcript segment from scoring twice.
- Standard advantage games require a two-point lead.
- No-Ad games end on the next point after 40–40.
- A standard set is won at six games with a two-game lead, or through the configured tiebreak at 6–6.
- A deciding match tiebreak is represented as its own completed set.
- Reported speech scores are interpreted in server–receiver order.
- A reported score that is not exactly one legal point from the current state requires confirmation.

## Why event sourcing

The microphone and cloud network are both unreliable. An append-only event log gives the app deterministic recovery after interruption, allows complete undo and correction history, and makes local and remote scoreboards converge through idempotent event replay.
