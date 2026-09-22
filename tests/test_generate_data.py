import csv
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1] / "scripts"))
import generate_date as generator


def test_funnel_steps_are_ordered():
    assert generator.FUNNEL_STEPS == [
        "view_home", "view_product", "add_to_cart", "checkout", "purchase"
    ]


def test_advance_probabilities_are_valid():
    assert all(0 < p <= 1 for p in generator.ADVANCE_PROB.values())


def test_make_event_normalizes_empty_product_id():
    event = generator.make_event(
        1, "U00001", "view_home", generator.datetime(2026, 8, 1),
        "mobile", "direct", None
    )
    assert event["product_id"] == ""
    assert event["event_id"] == 1
    assert event["user_id"] == "U00001"


def test_generated_visit_has_valid_schema():
    generator.random.seed(42)
    events, _ = generator.gen_visit_events("U00001", 1)

    assert events
    required = {
        "event_id", "user_id", "event_name", "event_timestamp",
        "device_type", "channel", "product_id"
    }
    assert all(set(e) == required for e in events)
    assert all(e["user_id"] == "U00001" for e in events)
    assert all(e["event_name"] in generator.FUNNEL_STEPS for e in events)


def test_generated_event_ids_are_sequential_within_visit():
    generator.random.seed(42)
    events, next_id = generator.gen_visit_events("U00001", 100)

    ids = [e["event_id"] for e in events]
    assert ids == list(range(100, 100 + len(events)))
    assert next_id == 100 + len(events)
