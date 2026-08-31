---
name: matt:run-feedback
description: "Analyze a run against the training plan and generate data-dense feedback with per-mile split breakdown, effort classification, and trend context. Use when the user says 'give me feedback on my run', 'analyze my run', 'run feedback', 'how was my run', or '/run-feedback'. Optionally accepts a date argument (e.g., '/run-feedback July 6')."
---

# Run Feedback

Generate data-dense, numbers-first analysis of a run against the training plan prescription. Not hand-wavy commentary -- use all the data: pace, HR, elevation, weather, sleep, morning readiness, and historical baselines.

## Steps

1. **Sync latest data**

```bash
curl -s -X POST "https://training.localhost/api/sync" | python3 -m json.tool
```

2. **Identify the target run**

If the user specified a date, use it. Otherwise, find the most recent run:

```bash
curl -s "https://training.localhost/api/activities?type=Run&limit=5"
```

Pick the run matching the requested date, or the most recent. Note its `strava_id`, `start_date_local`, `distance`, `moving_time`, `average_speed`, `average_heartrate`, `max_heartrate`, `total_elevation_gain`, and weather fields.

3. **Fetch splits**

```bash
curl -s "https://training.localhost/api/activities/{strava_id}/splits"
```

This returns per-mile splits with: `split_index`, `distance`, `elapsed_time`, `moving_time`, `elevation_diff` (meters), `average_speed` (m/s), `average_heartrate`, `pace_zone`.

4. **Get plan prescription for that date**

```bash
curl -s "https://training.localhost/api/plan/status"
```

Find the day matching the run's date. Extract: `plan.type`, `plan.miles`, `plan.label`, `plan.detail`. Map the detail to an effort type using the plan's glossary (e.g., "easy" = 9:30-10:00/mi, "tempo" = race pace ~8:30/mi).

5. **Compute baselines from recent history**

```bash
curl -s "https://training.localhost/api/activities?type=Run&limit=20"
```

From the last 20 runs, compute:
- **Easy HR baseline**: average of avg_heartrate from recent runs where distance was 3-4mi and average_speed was in easy range (2.5-2.9 m/s, i.e., ~9:15-10:45/mi)
- **Pace-at-HR trend**: for runs at similar HR, how has pace changed over time?
- **Recent elevation context**: typical elevation gain for this runner's routes

6. **Pull morning readiness from the health DB**

Apple Health data (sleep, resting HR, HRV, respiration, and ~40 other series) is pushed from the phone into a SQLite table `daily_metrics (date, metric, value, units)`. It is NOT part of `/api/sync`, so read the file directly. Sleep is filed under the date it ended, so `date = {run_date}` is the night before that morning's run.

Set `RUN_DATE` to the run's `start_date_local` date (YYYY-MM-DD), then:

```bash
DB="$HOME/Documents/GitHub/training-plan/data/training.db"
RUN_DATE={run_date}

# Run-day readiness snapshot
sqlite3 -header -column "$DB" "
SELECT metric, ROUND(value,2) AS value, units
FROM daily_metrics
WHERE date = '$RUN_DATE'
  AND metric IN ('sleep_total','sleep_core','sleep_rem','sleep_deep','sleep_awake',
                 'sleep_start_offset','sleep_end_offset',
                 'resting_heart_rate','heart_rate_variability','respiratory_rate')
ORDER BY metric;"

# 30-day baselines for RHR / HRV / respiration (each an independent Apple daily
# aggregate; no bad-day exclusion is needed or wanted)
sqlite3 -header -column "$DB" "
SELECT metric, ROUND(AVG(value),1) AS baseline_30d, COUNT(*) AS n
FROM daily_metrics
WHERE metric IN ('resting_heart_rate','heart_rate_variability','respiratory_rate')
  AND date >= date('$RUN_DATE','-30 day') AND date < '$RUN_DATE'
GROUP BY metric;"

# 30-day sleep baseline, excluding implausible >12h nights
sqlite3 -header -column "$DB" "
SELECT ROUND(AVG(value),2) AS sleep_total_30d, COUNT(*) AS n
FROM daily_metrics
WHERE metric='sleep_total' AND value <= 12
  AND date >= date('$RUN_DATE','-30 day') AND date < '$RUN_DATE';"
```

The `value <= 12` guard drops one bad sleep shape: an old-format night double-counted past 12h. Resting HR, HRV, and respiration get no such filter -- each is its own Apple daily aggregate, so a day whose raw `heart_rate` series is a single sample (common lately) still carries a valid RHR and HRV, and excluding it would only shrink the baseline. A run date can legitimately have no health row at all (watch not worn); if the snapshot is empty, say so and skip the readiness section rather than inventing numbers.

7. **Generate analysis**

Build `analysis_json` (structured data) and `narrative` (markdown text). The narrative MUST follow this structure:

**Header line**: distance (mi), time, avg pace, avg HR, max HR, weather feels-like temp

**Per-mile breakdown** (one line per split):
- Mile N -- pace, HR, elevation gain/loss in feet, and what the numbers mean in context of this specific run. Reference the plan prescription. Note inflection points (where pace jumped, where HR spiked, where elevation explains or doesn't explain the data).

**Effort summary**:
- What was prescribed vs what was run (use the glossary pace ranges)
- Avg HR vs personal easy baseline (compute the delta, state it as a number)
- Heat-adjusted effort: if feels-like >= 80°F, note that heat adds roughly 5-8 bpm to equivalent cool-weather HR. Classify the heat-adjusted effort.

**Elevation analysis**:
- Total gain in feet
- Distribution across miles (which mile had the most climb)
- Whether elevation explains the pace/HR pattern or if effort was independently high

**Trend context**:
- How this run's HR compares to recent runs at the same prescription
- Any fitness signals (pace improving at same HR, or HR dropping for same pace)
- Heat acclimatization signal if applicable

**Readiness context** (from the health DB; skip the whole section if there was no health row for the date):
- Sleep the night before: total hours + stage breakdown (deep / REM / core), vs the 30-day sleep average (state the delta)
- Morning RHR vs 30-day baseline (state the delta in bpm; elevated flags accumulated fatigue or illness)
- HRV vs 30-day baseline (state the delta in ms; a drop signals reduced recovery)
- Respiratory rate vs baseline (an elevated rate is a secondary illness/stress signal)
- Tie it to the run's ACTUAL avg HR from the Effort summary above, not a prediction: if a readiness signal is off and the run's HR ran high for its pace, name the link (e.g. "HRV down 15ms and the run's HR sat 6 bpm over the easy baseline -- the cost showed up as fatigue, not heat").

**Recovery implication**:
- What's the next planned workout?
- Does this run's effort level change how that workout should be approached?
- Fold in readiness: short sleep, elevated RHR, or suppressed HRV is a reason to hold back the next hard session; a fully-recovered profile is a green light.

All numbers must use actual data, not approximations. Cite the specific values from the splits, weather, readiness snapshot, and baseline computations.

8. **Post the feedback**

```bash
curl -s -X POST "https://training.localhost/api/activities/{strava_id}/feedback" \
  -H "Content-Type: application/json" \
  -d '{
    "plan_date": "YYYY-MM-DD",
    "plan_id": "10k-oct-2026",
    "prescribed_type": "easy",
    "prescribed_miles": 3,
    "analysis_json": "{...}",
    "narrative": "..."
  }'
```

9. **Confirm to the user**

Print a brief summary of the key finding (e.g., "Feedback saved for your July 9 run. Key takeaway: ran 34s/mi faster than prescribed easy pace, HR 5 bpm above your baseline, on 5.2h sleep and HRV down 10ms."). The full narrative is on the plan page now.
