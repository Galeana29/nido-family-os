# Event Ledger

**Never overwrite the plan with reality.**

The canonical ledger is append-oriented. Once an event may have synchronized, do not silently rewrite history. Corrections use explicit correction/supersession semantics; deletion uses tombstones.

Long-running activities share a stable `logicalSessionID`, e.g. NapStarted(A) → NapEnded(A). Watch/widget/Siri retries must be idempotent.

Initial taxonomy includes childWoke, mealStarted/Ended/Rated, napStarted/Ended, nightSleepStarted/Ended, nightWake, breastfeedStarted/Ended, diaperChanged, waterLogged, routine transitions, modeChanged, weightRecorded, healthNoteRecorded, calendarConflictAcknowledged and eventCorrected.

Derived state such as `isSleeping` is a projection, not a second canonical truth.

At Operational Day close, persist a versioned `DayPlanSnapshot` of what the caregiver actually saw so retroactive corrections do not silently rewrite historical experience.
