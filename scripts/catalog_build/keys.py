import hashlib

DURABLE_KEY_COLUMNS = {
    "price_card": ("price_series_id",),
    "model_revision": ("model_id",),
    "client_revision": ("client_id",),
    "model_alias": ("namespace_id", "alias"),
    "offering_revision": ("offering_id",),
    "offering_route": ("offering_id", "upstream_offering_id"),
    "plan_revision": ("plan_id",),
    "unit_rate": ("unit_rate_series_id",),
    "pricing_rule_revision": ("rule_key",),
    "price_gap": ("namespace_id", "label"),
}
SURROGATE_COLUMN = {table: f"{table}_id" for table in DURABLE_KEY_COLUMNS}
SURROGATE_HEX_DIGITS = 15


def durable_key(table: str, row: dict) -> str:
    return "|".join(str(row.get(column) or "") for column in DURABLE_KEY_COLUMNS[table])


def surrogate_id(table: str, key: str, valid_from: str, recorded_at: str) -> int:
    digest = hashlib.sha256(
        "|".join((table, key, valid_from, recorded_at)).encode("utf-8")).hexdigest()
    return int(digest[:SURROGATE_HEX_DIGITS], 16)


def offering_id(channel_id: str, model_id: str, variant: str) -> str:
    suffix = f"@{variant}" if variant else ""
    return f"{channel_id}/{model_id}{suffix}"


def price_series_id(series: dict) -> str:
    parts = [series["offering_id"], series["service_tier"], series["region_id"],
             series["price_unit_id"]]
    optional = (("window", "window_id"), ("plan", "plan_id"),
                ("via", "upstream_offering_id"), ("term", "commitment_term"))
    suffix = "".join(f"/{label}:{series[column]}" for label, column in optional
                     if series.get(column) is not None)
    return "/".join(parts) + suffix


def unit_rate_series_id(series: dict) -> str:
    head = (f"{series['unit_id']}>{series['value_unit_id']}/{series['rate_kind']}"
            f"/{series['region_id']}")
    optional = (("channel", "channel_id"), ("plan", "plan_id"), ("min", "min_purchase"))
    return head + "".join(f"/{label}:{series[column]}" for label, column in optional
                          if series.get(column) is not None)
