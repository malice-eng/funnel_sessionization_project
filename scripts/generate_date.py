"""
Generates synthetic clickstream event data for the funnel + sessionization project.

Simulates users visiting an e-commerce site across multiple "visits" (which may or
may not turn into distinct sessions once we apply a 30-minute inactivity threshold
in dbt). Each visit walks through a funnel:

    view_home -> view_product -> add_to_cart -> checkout -> purchase

with realistic dropoff probability at each step, plus some noise events
(view_home -> view_product -> view_home again, etc.) and randomized timestamps
with occasional long gaps *within* a visit, so the sessionization logic in dbt
has real gaps-and-islands cases to resolve (not just one session per visit).

Output: dbt/seeds/raw_events.csv
"""

import csv
import random
from datetime import datetime, timedelta

random.seed(42)

N_USERS = 500
DAYS_OF_HISTORY = 45
OUTPUT_PATH = "dbt/seeds/raw_events.csv"

FUNNEL_STEPS = ["view_home", "view_product", "add_to_cart", "checkout", "purchase"]

# Probability of advancing to the NEXT funnel step, per step
ADVANCE_PROB = {
    "view_home": 0.75,
    "view_product": 0.55,
    "add_to_cart": 0.45,
    "checkout": 0.70,
}

PRODUCT_IDS = [f"P{str(i).zfill(4)}" for i in range(1, 121)]
DEVICE_TYPES = ["desktop", "mobile", "tablet"]
CHANNELS = ["organic_search", "paid_search", "email", "direct", "social"]


def random_start_time():
    start = datetime(2026, 8, 1)
    day_offset = random.randint(0, DAYS_OF_HISTORY - 1)
    seconds_into_day = random.randint(6 * 3600, 23 * 3600)  # active hours 6am-11pm
    return start + timedelta(days=day_offset, seconds=seconds_into_day)


def gen_visit_events(user_id, event_id_counter):
    """Generate one 'visit' worth of events for a user, walking the funnel
    with dropoff, and occasionally re-browsing (view_home <-> view_product loops).
    Returns a list of event rows and the updated event_id_counter."""

    events = []
    t = random_start_time()
    device = random.choice(DEVICE_TYPES)
    channel = random.choice(CHANNELS)
    product_id = random.choice(PRODUCT_IDS)

    step_index = 0
    # small chance of a couple of browse loops before committing to the funnel
    browse_loops = random.choices([0, 1, 2], weights=[0.6, 0.3, 0.1])[0]

    for _ in range(browse_loops):
        events.append(make_event(event_id_counter, user_id, "view_home", t, device, channel, None))
        event_id_counter += 1
        t += timedelta(seconds=random.randint(5, 90))
        events.append(make_event(event_id_counter, user_id, "view_product", t, device, channel, random.choice(PRODUCT_IDS)))
        event_id_counter += 1
        t += timedelta(seconds=random.randint(5, 120))

    while step_index < len(FUNNEL_STEPS):
        step = FUNNEL_STEPS[step_index]
        pid = product_id if step in ("view_product", "add_to_cart", "checkout", "purchase") else None
        events.append(make_event(event_id_counter, user_id, step, t, device, channel, pid))
        event_id_counter += 1

        if step == "purchase":
            break

        prob = ADVANCE_PROB.get(step, 0)
        if random.random() > prob:
            break  # user drops off here

        # Time gap to next event. Occasionally a LONG gap (user got distracted,
        # came back later) so sessionization has real gaps to find within a "visit".
        if random.random() < 0.08:
            t += timedelta(minutes=random.randint(35, 240))  # long gap -> new session
        else:
            t += timedelta(seconds=random.randint(8, 180))  # normal within-session gap

        step_index += 1

    return events, event_id_counter


def make_event(event_id, user_id, event_name, ts, device, channel, product_id):
    return {
        "event_id": event_id,
        "user_id": user_id,
        "event_name": event_name,
        "event_timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "device_type": device,
        "channel": channel,
        "product_id": product_id if product_id else "",
    }


def main():
    all_events = []
    event_id_counter = 1

    for user_num in range(1, N_USERS + 1):
        user_id = f"U{str(user_num).zfill(5)}"
        n_visits = random.choices([1, 2, 3, 4, 5], weights=[0.35, 0.30, 0.20, 0.10, 0.05])[0]

        for _ in range(n_visits):
            visit_events, event_id_counter = gen_visit_events(user_id, event_id_counter)
            all_events.extend(visit_events)

    all_events.sort(key=lambda e: e["event_timestamp"])

    with open(OUTPUT_PATH, "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["event_id", "user_id", "event_name", "event_timestamp", "device_type", "channel", "product_id"],
        )
        writer.writeheader()
        writer.writerows(all_events)

    print(f"Generated {len(all_events)} events for {N_USERS} users -> {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
