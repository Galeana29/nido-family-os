# Domain Model

## Design goal

The model must represent intention, resolved plans and reality separately.

## Household

```swift
struct Household {
    let id: HouseholdID
    var name: String
    var timezone: TimeZone
    var settings: HouseholdSettings
    let createdAt: Date
}
```

## Person

```swift
enum PersonRole {
    case child
    case parent
    case caregiver
}

struct Person {
    let id: PersonID
    let householdID: HouseholdID
    var role: PersonRole
    var displayName: String
    var birthDate: Date?
}
```

## CarePlan

Contains family goals and constraints.

```swift
struct CarePlan {
    let id: CarePlanID
    let householdID: HouseholdID
    var instructions: [CareInstruction]
    var activePrograms: [ProgramID]
}
```

## CareInstruction

```swift
struct CareInstruction {
    enum AuthorType {
        case caregiver
        case clinician
        case dietitian
        case therapist
        case otherProfessional
    }

    let id: CareInstructionID
    let authorType: AuthorType
    var authorName: String?
    var text: String
    var priority: Int
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var isLocked: Bool
    var sourceReference: String?
}
```

Locked instructions cannot be silently changed by automatic routines.

## RoutineTemplate

A reusable routine definition.

```swift
struct RoutineTemplate {
    let id: RoutineTemplateID
    let householdID: HouseholdID
    var name: String
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var version: Int
    var rules: [RoutineRule]
}
```

## RoutineRule

```swift
struct RoutineRule {
    let id: RoutineRuleID
    let templateID: RoutineTemplateID
    let ownerID: PersonID?
    var category: RoutineCategory
    var timingRule: TimingRule
    var priority: RoutinePriority
    var duration: DurationRange?
    var notificationPolicy: NotificationPolicy
    var fallbackPolicy: FallbackPolicy?
    var dependencies: [RoutineDependency]
}
```

## RoutineCategory

```text
sleep
feeding
breastfeeding
health
hygiene
development
outdoor
personal
household
appointment
travel
prep
shopping
other
```

## RoutinePriority

```text
P0 safety / medical
P1 anchor
P2 important
P3 flexible
P4 optional
```

## DailyOccurrence

A resolved, date-specific manifestation of a routine rule.

```swift
struct DailyOccurrence {
    let id: OccurrenceID
    let ruleID: RoutineRuleID
    let date: LocalDate

    let originalPlan: PlannedTiming
    var resolvedTiming: ResolvedTiming

    var status: OccurrenceStatus
    var adjustmentReasons: [AdjustmentReason]
}
```

## OccurrenceStatus

Canonical state vocabulary:

```text
upcoming
ready
active
completed
skipped
adjusted
cancelled
```

Design/Figma should use the same vocabulary.

## LoggedEvent

```swift
struct LoggedEvent {
    let id: EventID
    let householdID: HouseholdID
    let personID: PersonID?

    let type: EventType
    let startedAt: Date
    var endedAt: Date?

    var metadata: EventMetadata

    let source: EventSource
    let createdBy: PersonID?
    let createdAt: Date
    var modifiedAt: Date
}
```

## EventSource

```text
app
watch
voice
widget
siri
imported
automation
```

## MealLog metadata

```text
rating:
  none
  taste
  small
  normal
  more

foods[]
behaviors[]
notes?
```

Potential behaviors:

```text
closedMouth
threwFood
distracted
tired
askedForMilk
other
```

Do not require detail for every meal.

## Sleep metadata

```text
sleepType:
  night
  nap1
  nap2
  other

assistance:
  none
  cuddle
  breastfeed
  other
```

## Breastfeed / milk metadata

```text
context:
  wake
  nap
  bedtime
  comfort
  other

planned: Bool
```

The `planned` distinction is useful when analyzing structured versus on-demand feeding patterns without requiring volume measurement.
