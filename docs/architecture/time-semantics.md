# Time Semantics

## Operational Day
Calendar date and `OperationalDayID` are different. Child planning is wake-to-next-primary-wake, anchored to the local date of the primary morning wake. A night sleep can cross midnight while closing the prior operational day.

Night wakes are events inside one logical night-sleep session. The next primary wake closes it and opens the next operational day.

## Types
Persist event timestamps as instants (`Date`) with time-zone context. Use LocalDate for labels/effective dates and wall-clock values for routine-template intent. Never persist schedule meaning only as strings such as `14:15`.

## DST tests
Spring-forward elapsed duration uses instants; fall-back repeated local hour cannot duplicate logical identity; relative durations use elapsed time while anchors such as 19:30 remain local-wall-clock preferences.

## Travel
Historical event instants never change. Routine anchors are reinterpreted in an active travel timezone only by explicit policy.
