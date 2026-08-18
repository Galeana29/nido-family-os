# ADR 0002 — Local-first operation

## Status
Accepted

## Decision
Core routines, logging and re-resolution must work without network connectivity.

## Consequence
Local persistence is authoritative for immediate UX; cloud synchronization is asynchronous.
