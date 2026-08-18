# NIDO — Family Routine OS

> A calm, adaptive operating system for family routines.

NIDO is a local-first family routine engine that helps answer: what matters now, what do I do, what happened, and what changes next?

## Product loop
**PLAN → NOW → DO → OBSERVE → LOG → RECALCULATE → NEXT**

## Current status
NIDO has moved from specification-only architecture to **executable engine proof**. The repository contains Swift 6 domain/engine packages and scenario tests. Conceptual documentation is frozen except where needed to unblock executable behavior.

## Doctrine
Deterministic/explainable engine; UI never calculates policy; plan ≠ reality; local-first/sync-ready schema; AI parses/explains but never writes authority; caregiver override inside hard safety constraints; stability beats micro-optimization; no guilt language/streaks/overdue parenting.

## Read next
Use **[docs/INDEX.md](docs/INDEX.md)** as the canonical documentation map.

## Run
```bash
swift test
```

Canonical audit regression: Nap1 end 11:31 with +195/+210/+225 resolves Nap2 **14:46 / 15:01 / 15:16**, never the invalid handwritten 14:45.

## License
No open-source license is granted at this stage.
