# Funnel & Sessionization Analytics — dbt + Postgres

A SQL-first analytics project that turns raw clickstream events into:
1. **Sessions** — using a classic "gaps and islands" pattern (`LAG()` + running `SUM()`) with a 30-minute inactivity timeout
2. **Funnel analysis** — conversion rates through `view_home → view_product → add_to_cart → checkout → purchase`, overall and cut by channel/device

Everything downstream of data generation is pure SQL, orchestrated with dbt.

## Stack
- **Postgres** (local, via Docker) — the warehouse
- **dbt-postgres** — transformations, tests, docs
- **Python** — only used to generate synthetic seed data (no pandas/etc. needed downstream)

## Project layout
```
funnel_sessionization_project/
├── docker-compose.yml           # spins up local Postgres
├── scripts/generate_data.py     # generates dbt/seeds/raw_events.csv
└── dbt/
    ├── dbt_project.yml
    ├── profiles_example.yml     # copy to ~/.dbt/profiles.yml
    ├── seeds/raw_events.csv     # ~3,800 synthetic events, 500 users
    ├── macros/funnel_step_order.sql
    └── models/
        ├── staging/
        │   ├── stg_events.sql       # cleaned, typed, deduped events
        │   └── schema.yml           # source/seed tests
        ├── intermediate/
        │   ├── int_events_sessionized.sql   # gaps-and-islands sessionization
        │   └── int_sessions.sql             # one row per session
        └── marts/
            ├── fct_sessions.sql         # final session fact table
            ├── fct_funnel_steps.sql     # boolean flags per funnel step per session
            ├── funnel_conversion.sql    # conversion rates: overall / by channel / by device
            └── schema.yml
```

## Setup

### 1. Start Postgres
```bash
docker-compose up -d
```
This creates a Postgres 16 instance on `localhost:5432` with:
- user: `funnel_user` / password: `funnel_pass`
- database: `funnel_analytics`

### 2. Install dbt
```bash
pip install dbt-postgres
```

### 3. Configure the dbt profile
```bash
mkdir -p ~/.dbt
cp dbt/profiles_example.yml ~/.dbt/profiles.yml
```

### 4. Generate the synthetic event data
```bash
cd funnel_sessionization_project
python3 scripts/generate_data.py
```
This writes `dbt/seeds/raw_events.csv` — ~3,800 events across 500 users over 45 days,
simulating realistic funnel dropoff and randomized time gaps (including some long
gaps *within* a user's activity, so the sessionization logic has real cases to split on).

### 5. Run the pipeline
```bash
cd dbt
dbt seed    # load raw_events.csv into Postgres
dbt run     # build staging -> intermediate -> marts
dbt test    # run data quality tests
```

### 6. Explore the results
```bash
psql -h localhost -U funnel_user -d funnel_analytics
```
```sql
select * from analytics.funnel_conversion order by segment_type, segment_value;
select * from analytics.fct_sessions limit 20;
select * from analytics.fct_funnel_steps limit 20;
```

## The interesting SQL

**Sessionization (`int_events_sessionized.sql`)** — the gaps-and-islands pattern:
```sql
lag(event_timestamp) over (partition by user_id order by event_timestamp) as prev_event_timestamp
```
then a flag whenever the gap exceeds 30 minutes, and a running `sum()` of that flag
to assign a stable, incrementing session number per user.

**Funnel step reached (`int_sessions.sql`)** — mapping event names to an ordinal
step via a macro, then taking `max()` per session to find how far each session
got, without needing a self-join or `EXISTS` subqueries per step.

**Conditional aggregation (`funnel_conversion.sql`)** — the standard funnel BI
pattern: `sum(reached_x::int)` per segment, then dividing consecutive steps to
get step-over-step conversion rates.

## Ideas to extend
- Add a `dim_users` model with signup date, cohort, or acquisition source
- Build cohort retention curves (session-based, week-over-week)
- Add a **time-to-purchase** metric: `purchase` timestamp minus session `session_start`
- Swap the synthetic seed for a real public clickstream dataset
- Add `dbt-utils` for `date_spine` and generate a full daily funnel trend table
