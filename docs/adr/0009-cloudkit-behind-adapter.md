# ADR 0009 — Cloud sync behind repository adapters

## Status
Accepted

## Decision
Domain and Routine Engine layers do not depend directly on CloudKit.

## Consequence
CloudKit/CKSyncEngine can evolve without leaking into core scheduling behavior.
