# Intelligence Architecture

## Principle

AI is an interpreter and explainer, not the authority.

## Core pipeline

```text
User language / voice
        ↓
Transcription
        ↓
Parser / Foundation Model
        ↓
CandidateAction
        ↓
Domain validation
        ↓
Confirmation when ambiguity matters
        ↓
Command
        ↓
Event Ledger
        ↓
Routine Engine
```

Never:

```text
LLM → direct database write
```

## CandidateAction

Example:

User says:

> “She fell asleep about ten minutes ago.”

Current time: 14:23.

Candidate:

```json
{
  "intent": "startNap",
  "estimatedTime": "14:13",
  "confidence": 0.94
}
```

UI:

> Nap started at **2:13 PM** — correct?

Confirmation may be skipped only where confidence, reversibility and user preference make that safe.

## AI allowed tasks

- structured intent extraction;
- summarization;
- natural-language explanations of deterministic adjustments;
- descriptive weekly insights;
- search within user-owned logs;
- transforming unstructured daycare reports into draft events.

## AI prohibited authority

- changing locked clinician instructions;
- diagnosing illness;
- medication dose decisions;
- autonomously escalating/reducing feeding or weaning programs;
- inventing wake-window rules;
- making emergency triage decisions beyond deterministic safety routing.

## Explainability

The underlying reason comes from the engine.

AI can rewrite:

```text
nap2 shifted because nap1 ended 31 min late
```

into:

> “I moved the second nap 25 minutes because the first nap ended later than planned.”

But the model does not choose the 25-minute shift.

## Failure mode

If AI is unavailable:

- Routine Engine works;
- logging works;
- typed quick actions work;
- notifications work;
- Today works;
- Watch and widgets work.

This is mandatory.
