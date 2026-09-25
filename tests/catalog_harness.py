import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schema"
FIXTURE_DIR = ROOT / "tests" / "fixtures"
PRICE_AT = SCHEMA_DIR / "queries" / "price_at.sql"
UNIT_VALUE_AT = SCHEMA_DIR / "queries" / "unit_value_at.sql"

PRICE_AT_DEFAULTS = {
    "channel_id": None, "client_id": None, "variant": None, "known_at": None,
    "service_tier": "standard", "region_id": "global", "price_unit_id": "USD",
    "plan_id": None, "upstream_offering_id": None, "commitment_term": None,
    "window_id": None, "input_tokens": None,
}
UNIT_VALUE_DEFAULTS = {
    "known_at": None, "channel_id": None, "plan_id": None, "region_id": None,
}


def run_scripts(connection: sqlite3.Connection, directory: Path) -> None:
    for script in sorted(directory.glob("*.sql")):
        connection.executescript(script.read_text(encoding="utf-8"))


def open_catalog(with_fixtures: bool = True) -> sqlite3.Connection:
    connection = sqlite3.connect(":memory:")
    connection.row_factory = sqlite3.Row
    run_scripts(connection, SCHEMA_DIR)
    if with_fixtures:
        run_scripts(connection, FIXTURE_DIR)
    return connection


def price_at(connection: sqlite3.Connection, **params) -> dict:
    rows = connection.execute(
        PRICE_AT.read_text(encoding="utf-8"), {**PRICE_AT_DEFAULTS, **params}
    ).fetchall()
    cards = {row["price_card_id"] for row in rows}
    if len(cards) > 1:
        raise AssertionError(f"同一时点命中多张价目卡：{sorted(cards)}")
    rates = {row["meter_id"]: row["amount"] for row in rows}
    series = next(iter({row["price_series_id"] for row in rows}), None)
    return {"card": next(iter(cards), None), "series": series, "rates": rates,
            "rows": rows}


def unit_value_at(connection: sqlite3.Connection, **params) -> list:
    rows = connection.execute(
        UNIT_VALUE_AT.read_text(encoding="utf-8"), {**UNIT_VALUE_DEFAULTS, **params}
    ).fetchall()
    return [(row["rate_kinds"], row["value"]) for row in rows]


SCD2_DEFAULTS = {
    "valid_from": "2026-09-01T00:00:00Z", "date_basis": "inferred",
    "recorded_at": "2026-09-24T00:00:00Z", "source_id": "fixture-constructed",
}


def insert(connection: sqlite3.Connection, table: str, **values) -> None:
    columns = ", ".join(values)
    placeholders = ", ".join(f":{name}" for name in values)
    connection.execute(f"INSERT INTO {table} ({columns}) VALUES ({placeholders})",
                       values)
