# Documentation Index

Canonical map of every document in this repository. Conceptual docs are frozen per `AGENTS.md` (changes only to unblock executable behavior); normative docs for the current phase are listed first.

## Start here — normative

- [Vocabulary](vocabulary.md) — single naming authority (en/es)
- [Resolution algorithm](architecture/resolution-algorithm.md)
- [Time semantics](architecture/time-semantics.md)
- [System architecture](architecture/system-architecture.md)
- [Process topology](architecture/process-topology.md)

## Product

- [Vision](product/vision.md)
- [Product principles](product/product-principles.md)
- [Information architecture](product/information-architecture.md)
- [User stories](product/user-stories.md)
- [Feature specification](product/feature-spec.md)
- [Roadmap](product/roadmap.md)
- [Backlog](product/backlog.md)
- [Risks and non-goals](product/risks-and-non-goals.md)
- [Onboarding & template authoring](product/onboarding-template-authoring.md)

## Architecture

- [Routine engine](architecture/routine-engine.md)
- [Domain model](architecture/domain-model.md)
- [Event ledger](architecture/event-ledger.md)
- [Sync & collaboration](architecture/sync-collaboration.md)
- [Apple integrations](architecture/apple-integrations.md)
- [Intelligence](architecture/intelligence.md)
- [Notification / attention](architecture/notification-attention.md)

## Design

- [Design system](design/design-system.md)
- [Screen specifications](design/screen-specs.md)
- [Interaction specification](design/interaction-spec.md)
- [Content style](design/content-style.md)
- [Figma handoff](design/figma-handoff.md)

## Engineering

- [iOS project structure](engineering/ios-project-structure.md)
- [Testing strategy](engineering/testing-strategy.md)
- [Observability](engineering/observability.md)

## Safety

- [Health boundaries](safety/safety-health-boundaries.md)
- [Privacy & security](safety/privacy-security.md)

## Operations & research

- [Product decision log](operations/decision-log.md)
- [Official platform references](research/official-platform-references.md)

## ADRs

- [0001 Native iOS first](adr/0001-native-ios-first.md)
- [0002 Local-first](adr/0002-local-first.md)
- [0003 Deterministic routine engine](adr/0003-deterministic-routine-engine.md)
- [0004 Event ledger](adr/0004-event-ledger.md)
- [0005 Calendar as external constraint](adr/0005-calendar-as-external-constraint.md)
- [0006 AI candidate actions](adr/0006-ai-candidate-actions.md)
- [0007 Attention budget](adr/0007-attention-budget.md)
- [0008 No streak gamification](adr/0008-no-streak-gamification.md)
- [0009 CloudKit behind adapter](adr/0009-cloudkit-behind-adapter.md)
- [0010 Shared design/domain language](adr/0010-shared-design-domain-language.md)
- [0011 Persistence and sync](adr/0011-persistence-and-sync.md) — Proposed, spike required
- [0012 Deployment target](adr/0012-deployment-target.md)
- [0013 HealthKit](adr/0013-healthkit.md)
- [0014 Analytics](adr/0014-analytics.md)

## Examples

- [`examples/sample-day.json`](../examples/sample-day.json) — canonical imperfect day inputs (expected outputs live in executable tests)
- [`examples/sample-care-plan.yaml`](../examples/sample-care-plan.yaml)
