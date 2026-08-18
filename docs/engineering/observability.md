# Observability

## Product principle

Instrumentation exists to improve the product, not to maximize engagement.

## Useful metrics

```text
interactions_per_event
quick_log_completion_time
manual_reschedule_rate
routine_override_rate
notification_open_rate
notification_dismiss_rate
voice_parse_success_rate
voice_correction_rate
chaos_mode_usage
program_pause_rate
```

## North-star proxies

### Average interactions per meaningful event

Target hypothesis:

```text
≤ 2
```

### Unnecessary notification rate

Repeated dismissal without later action suggests a notification may not deserve interruption.

### Manual reschedule rate

High rate may indicate the Routine Engine is not matching real life.

## Privacy

Avoid analytics payloads containing:

- free-form health notes;
- meal text;
- exact child identity;
- voice transcripts;
- calendar titles.

Instrumentation should use event categories and anonymized/aggregated metadata where possible.

## Debug logging

Routine Engine debug builds should be able to emit:

```text
input snapshot hash
rule evaluation trace
adjustment reasons
resolved occurrence list
```

This enables reproducible scheduling bug reports without requiring production PII.
