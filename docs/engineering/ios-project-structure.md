# iOS Project Structure

## Goal

Keep domain and scheduling logic independently testable while allowing system extensions to consume the same resolved state.

## Proposed modules

```text
NidoApp
│
├── NidoDomain
├── NidoRoutineEngine
├── NidoPersistence
├── NidoCloudSync
├── NidoDesignSystem
├── NidoAppleServices
├── NidoIntelligence
│
├── FeatureToday
├── FeaturePlan
├── FeatureMeals
├── FeatureSleep
├── FeaturePrograms
├── FeatureInsights
├── FeatureHousehold
│
├── NidoWidgets
├── NidoLiveActivities
├── NidoIntents
└── NidoWatch
```

## Dependency direction

```text
FeatureToday ───────┐
FeaturePlan ────────┼──► NidoDomain
FeatureMeals ───────┤
FeatureSleep ───────┘

NidoRoutineEngine ───► NidoDomain
NidoPersistence ─────► NidoDomain
NidoCloudSync ───────► NidoDomain
NidoAppleServices ───► NidoDomain protocols
```

`NidoDomain` imports no SwiftUI and no CloudKit.

## Core domain commands

Examples:

```text
StartMealCommand
EndMealCommand
RateMealCommand
StartNapCommand
EndNapCommand
LogBreastfeedCommand
DelayOccurrenceCommand
SkipOccurrenceCommand
SetDayModeCommand
```

## Feature stores

Feature state should consume projections from domain/application services.

Do not reproduce business logic in SwiftUI views.

## Fixture architecture

Create deterministic fixtures:

```text
HouseholdFixture
RoutineTemplateFixture
CarePlanFixture
DayScenarioFixture
```

Figma prototype scenarios should have equivalent code fixtures.

## Preview support

Every major SwiftUI component should support previews for:

- light/dark;
- large Dynamic Type;
- active/completed/adjusted states;
- long localized copy.
