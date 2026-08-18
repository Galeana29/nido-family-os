# Privacy & Security

## Data sensitivity

NIDO can contain intimate household data:

- child sleep;
- feeding;
- nursing/milk;
- weight;
- health notes;
- calendar commitments;
- caregiver routines.

Privacy is product architecture, not a settings-page feature.

## Principles

### Local-first

Core data lives locally and functions without cloud access.

### Minimize data

Do not collect information because it may be analytically interesting.

### Permission in context

Request permissions when the user enables the function requiring them.

Examples:

- Calendar when enabling conflict detection;
- Speech when first using voice;
- alarm authorization when configuring an alarm.

### Least access

Request only the access necessary.

### No advertising profile

Household health/routine data must not become advertising-targeting data.

## Calendar privacy

Prefer processing calendar conflicts locally.

Persist only what the product actually needs.

Avoid unnecessary retention of full external event descriptions.

## Voice privacy

Avoid long-term storage of raw voice/audio unless explicitly required and consented.

Prefer structured action extraction.

## Analytics

Do not send free-form health notes or voice transcripts to analytics.

## Export/delete

Long-term product requirements:

- export household data;
- delete household data;
- leave shared household;
- revoke caregiver access.

## Sharing

Household sharing should have explicit role scopes.

Do not assume all caregiver personal routines should be visible to every household member.
