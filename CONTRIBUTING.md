# Contributing to NIDO

NIDO is currently in early product architecture and implementation planning.

## Branches

Use short-lived branches:

- `feature/...`
- `engine/...`
- `design/...`
- `fix/...`
- `docs/...`

## Commit philosophy

Prefer small commits with one coherent intent.

## Pull requests

Every PR should describe:

- the user problem;
- why the change is necessary;
- domain/engine impact;
- safety/privacy impact;
- validation performed.

## Architecture changes

Material architecture decisions require an ADR under `docs/adr/`.

## Routine Engine changes

Every behavior change requires deterministic scenario tests.

## Product language

Never use failure/guilt language for routine variance.

Avoid claims that imply medical diagnosis or causation without appropriate evidence.
