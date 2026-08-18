# ADR 0006 — AI produces candidate actions

## Status
Accepted

## Decision
Model output never directly mutates persistent state.

Flow:

`input → model/parser → CandidateAction → validation → confirmation if needed → domain command → event ledger`
