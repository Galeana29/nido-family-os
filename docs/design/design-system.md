# NIDO Design System

## Design direction

**Scandinavian warm clinical.**

The interface should feel calm, adult, premium and precise without looking sterile.

Avoid conventional “baby app” aesthetics such as excessive pastel pink, cartoon animals or rainbow decoration.

## Design principles

1. One primary decision at a time.
2. One-hand operation.
3. Progressive disclosure.
4. System-native behavior where possible.
5. Red is reserved for genuine attention/safety.
6. Motion explains causality; it does not decorate.
7. Difficult days are visually simplified, not marked as failure.

## Color tokens

Initial visual exploration values; validate contrast before production.

```text
brand.forest        #426A5A
brand.soft          #E5EFE9
canvas.warm         #F8F6F1
surface.primary     #FFFFFF
text.primary        #202522
text.secondary      #69716C
accent.warm         #C98567
```

Create semantic colors for:

```text
sleep
feeding
nursing
personal
health
success
attention
critical
```

Do not bind domain meaning directly to raw hex colors.

## Dark mode

Use semantic tokens:

```text
surfacePrimary
surfaceSecondary
textPrimary
textSecondary
accent
separator
```

Do not simply invert the light palette.

## Typography

Use Apple system typography / SF Pro.

Suggested hierarchy:

```text
Display       32–34 bold
Screen title  28 bold
Card title    20–22 semibold
Body          17 regular
Secondary     15 regular
Caption       13 regular
```

All components must tolerate Dynamic Type.

## Spacing

4-point foundation.

```text
2xs  4
xs   8
s   12
m   16
l   24
xl  32
2xl 48
```

Screen horizontal padding: ~20pt as initial target.

## Radius

```text
small control  10
button         14
card           18
hero card      24
sheet          system
```

## Elevation

Minimal.

Prefer surface contrast and subtle separators over heavy ecommerce shadows.

The Now Card may have slightly stronger elevation.

## Motion

Typical transition:

```text
200–350 ms
soft spring
```

Use motion for:

- active → completed;
- schedule re-resolution;
- timeline shifts;
- sheet presentation.

Respect Reduce Motion.

## Iconography

Prefer SF Symbols for platform consistency.

Custom brand icons should be rare and purposeful.

Emoji may appear in prototypes but should not define the production icon system.

## Touch targets

Optimize for holding a child with one arm.

- important actions near the lower half of the screen;
- generous touch targets;
- no tiny inline controls for primary interactions;
- aim for completion in ≤2 taps.

## Core component library

```text
Nido/
├── Foundations
│   ├── Colors
│   ├── Typography
│   ├── Spacing
│   ├── Radius
│   ├── Iconography
│   └── Motion
├── Controls
│   ├── Button
│   ├── IconButton
│   ├── SegmentedControl
│   ├── Toggle
│   ├── Pill
│   └── Input
├── Cards
│   ├── NowCard
│   ├── NextCard
│   ├── InsightCard
│   ├── ProgramCard
│   ├── AlertCard
│   └── PersonalWindowCard
├── Timeline
│   ├── ExactEvent
│   ├── WindowEvent
│   ├── AnchorEvent
│   ├── FlexibleEvent
│   └── CurrentTimeMarker
├── Logging
│   ├── MealRating
│   ├── SleepControls
│   ├── NursingControls
│   └── QuickLog
└── Navigation
    ├── TabBar
    ├── Header
    ├── Sheet
    └── ContextMenu
```

## Canonical component states

```text
default
pressed
disabled
loading
active
completed
adjusted
overdue
error
```

Where domain states exist, align naming with domain vocabulary.
