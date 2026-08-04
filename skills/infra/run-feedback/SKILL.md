---
name: matt:run-feedback
description: "Analyze a run against the training plan and generate data-dense feedback with per-mile split breakdown, effort classification, and trend context. Use when the user says 'give me feedback on my run', 'analyze my run', 'run feedback', 'how was my run', or '/run-feedback'. Optionally accepts a date argument (e.g., '/run-feedback July 6')."
---

# Run Feedback

Generate data-dense, numbers-first analysis of a run against the training plan prescription. Not hand-wavy commentary -- use all the data: pace, HR, elevation, weather, and historical baselines.

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

6. **Generate analysis**

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

**Recovery implication**:
- What's the next planned workout?
- Does this run's effort level change how that workout should be approached?

All numbers must use actual data, not approximations. Cite the specific values from the splits, weather, and baseline computations.

7. **Post the feedback**

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

8. **Confirm to the user**

Print a brief summary of the key finding (e.g., "Feedback saved for your July 9 run. Key takeaway: ran 34s/mi faster than prescribed easy pace, HR 5 bpm above your baseline."). The full narrative is on the plan page now.
