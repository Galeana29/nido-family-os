# ADR 0015 — A web build carries the alpha

## Status
Accepted

## Decision
Ship the alpha as an installable web app: the engine compiled to WebAssembly, running inside the browser, with the event ledger held by the browser. Native iOS remains the product (ADR 0001); this is how the product gets tested before it can be built.

## Context
NIDO is developed on Windows. Xcode does not run there, and a rented Mac cannot install a build onto a phone over a cable — that path needs TestFlight, which needs the paid Apple Developer Program. The alpha would therefore be blocked behind hardware and a yearly fee before a single caregiver had ever used the app.

The seven days with a real caregiver are the only test that tells us whether NIDO resolves the problem it claims to. Blocking that test on tooling is the expensive mistake; a browser is not.

The architecture makes this cheap rather than a rewrite. `NidoRoutineEngine`, `NidoDomain` and `NidoTodayFeature` never import SwiftUI, so they compile to `wasm32-unknown-wasip1` unchanged and produce byte-identical output to the native build. Only `TodayScreen`, a thin view with no logic, is Apple-only. Foundation on WebAssembly carries its own time zone data, so the day resolves correctly with no filesystem at all.

## Consequence
- The web build must never grow scheduling logic of its own. It sends the ledger to the engine and renders the answer, exactly as the iOS app does. Two clients, one engine, no disagreement possible.
- `NidoWebBridge` is a pure function: one JSON request in, one JSON response out. Nothing is resident between calls, so nothing can drift.
- Durability in the browser is `localStorage`, not a database choice. ADR 0011 stays open: the web build never sees a store, only the ledger it holds.
- Notifications, widgets, calendar and Watch stay out of reach until the native app exists. The alpha tests the day, not the system surfaces.
- The module is about 57 MB (roughly 20 MB compressed), dominated by Foundation. It is cached once by the service worker and then works offline. Shrinking it — by cutting the ICU-backed formatting the presenter uses — is worth doing, and is not a blocker for the alpha.
