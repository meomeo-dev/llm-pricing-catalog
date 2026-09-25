from dataclasses import dataclass

from catalog_build import keys

SCD2_DEFAULT_COLUMNS = ("valid_from", "valid_to", "date_basis", "recorded_at",
                        "source_id")
PRICE_SERIES_DEFAULTS = {"service_tier": "standard", "region_id": "global",
                         "price_unit_id": "USD"}
PRICE_SERIES_COLUMNS = ("offering_id", "service_tier", "region_id", "price_unit_id",
                        "window_id", "plan_id", "upstream_offering_id",
                        "commitment_term")
UNIT_RATE_SERIES_COLUMNS = ("unit_id", "value_unit_id", "rate_kind", "region_id",
                            "channel_id", "plan_id", "min_purchase")
RULE_IDENTITY_COLUMNS = ("rule_key", "channel_id", "plan_id", "kind",
                         "reference_channel_id")
PLAN_IDENTITY_COLUMNS = ("plan_id", "channel_id", "display_name")
OFFERING_IDENTITY_COLUMNS = ("offering_id", "channel_id", "model_id", "variant")


class EntryError(ValueError):
    pass


@dataclass(frozen=True)
class Row:
    table: str
    values: dict
    origin: str


@dataclass(frozen=True)
class Entry:
    kind: str
    values: dict
    defaults: dict
    origin: str


def expand(entry: Entry) -> list[Row]:
    handler = HANDLERS.get(entry.kind)
    rows = handler(entry) if handler else [versioned(entry, entry.kind, entry.values)]
    return [Row(table, values, entry.origin) for table, values in rows]


def versioned(entry: Entry, table: str, values: dict) -> tuple[str, dict]:
    if table not in keys.DURABLE_KEY_COLUMNS:
        return table, dict(values)
    row = {column: entry.defaults[column] for column in SCD2_DEFAULT_COLUMNS
           if column in entry.defaults}
    row.update(values)
    missing = [c for c in ("valid_from", "date_basis", "recorded_at", "source_id")
               if c not in row]
    if missing:
        raise EntryError(f"{entry.origin}：{table} 缺少 {missing}，也没有 [defaults]")
    surrogate = keys.SURROGATE_COLUMN[table]
    row.setdefault(surrogate, keys.surrogate_id(
        table, keys.durable_key(table, row), row["valid_from"], row["recorded_at"]))
    return table, row


def split(values: dict, columns: tuple) -> tuple[dict, dict]:
    picked = {c: values[c] for c in columns if c in values}
    rest = {k: v for k, v in values.items() if k not in columns}
    return picked, rest


def decimal_text(entry: Entry, value) -> str:
    if not isinstance(value, str):
        raise EntryError(f"{entry.origin}：金额 {value!r} 必须写成字符串")
    return value


def price_series_of(entry: Entry, values: dict) -> dict:
    series = {**PRICE_SERIES_DEFAULTS,
              **{c: values[c] for c in PRICE_SERIES_COLUMNS if c in values}}
    if "offering_id" not in series:
        raise EntryError(f"{entry.origin}：价目卡缺少 offering_id")
    series["channel_id"] = series["offering_id"].split("/", 1)[0]
    series["price_series_id"] = keys.price_series_id(series)
    return series


def card_reference(entry: Entry, reference: dict) -> int:
    series = price_series_of(entry, reference)
    recorded_at = reference.get("recorded_at", entry.defaults.get("recorded_at"))
    return keys.surrogate_id("price_card", series["price_series_id"],
                             reference["valid_from"], recorded_at)


def rule_revision_reference(entry: Entry, reference: dict) -> int:
    recorded_at = reference.get("recorded_at", entry.defaults.get("recorded_at"))
    return keys.surrogate_id("pricing_rule_revision", reference["rule_key"],
                             reference["valid_from"], recorded_at)


def expand_price_card(entry: Entry) -> list[tuple[str, dict]]:
    values = dict(entry.values)
    series = price_series_of(entry, values)
    rates = values.pop("rates", None)
    if not rates:
        raise EntryError(f"{entry.origin}：价目卡缺少 rates")
    tiers = values.pop("tiers", [])
    excerpt = values.pop("excerpt", None)
    evidence = values.pop("evidence", [])
    if "derived_from_card" in values:
        values["derived_from_card_id"] = card_reference(
            entry, values.pop("derived_from_card"))
    if "derived_from_rule" in values:
        values["derived_from_rule_revision_id"] = rule_revision_reference(
            entry, values.pop("derived_from_rule"))
    card_values = {k: v for k, v in values.items() if k not in PRICE_SERIES_COLUMNS}
    card_values["price_series_id"] = series["price_series_id"]
    _, card = versioned(entry, "price_card", card_values)
    rows = [("price_series", series), ("price_card", card)]
    rows += price_rates(entry, card["price_card_id"], rates, tiers)
    rows += price_evidence(card, excerpt, evidence)
    return rows


def price_rates(entry: Entry, card_id: int, rates: dict, tiers: list) -> list:
    layers = [(0, rates)] + [(tier["min_tokens"], tier["rates"]) for tier in tiers]
    return [("price_rate", {"price_card_id": card_id, "meter_id": meter,
                            "context_min_tokens": min_tokens,
                            "amount": decimal_text(entry, amount)})
            for min_tokens, layer in layers for meter, amount in layer.items()]


def price_evidence(card: dict, excerpt, evidence: list) -> list:
    rows = []
    if excerpt is not None:
        rows.append(("price_evidence", {"price_card_id": card["price_card_id"],
                                        "source_id": card["source_id"],
                                        "stance": "primary", "excerpt": excerpt}))
    for item in evidence:
        rows.append(("price_evidence", {"price_card_id": card["price_card_id"], **item}))
    return rows


def expand_unit_rate(entry: Entry) -> list[tuple[str, dict]]:
    series, rest = split(entry.values, UNIT_RATE_SERIES_COLUMNS)
    series.setdefault("region_id", "global")
    series["unit_rate_series_id"] = keys.unit_rate_series_id(series)
    rest["value_amount"] = decimal_text(entry, rest.get("value_amount"))
    rest["unit_rate_series_id"] = series["unit_rate_series_id"]
    return [("unit_rate_series", series), versioned(entry, "unit_rate", rest)]


def expand_pricing_rule(entry: Entry) -> list[tuple[str, dict]]:
    identity, rest = split(entry.values, RULE_IDENTITY_COLUMNS)
    scope_models = rest.pop("scope_models", [])
    scope_meters = rest.pop("scope_meters", [])
    _, revision = versioned(entry, "pricing_rule_revision",
                            {"rule_key": identity["rule_key"], **rest})
    revision_id = revision["pricing_rule_revision_id"]
    rows = [("pricing_rule", identity), ("pricing_rule_revision", revision)]
    rows += [("pricing_rule_scope_model", {"pricing_rule_revision_id": revision_id,
                                           "model_id": m}) for m in scope_models]
    rows += [("pricing_rule_scope_meter", {"pricing_rule_revision_id": revision_id,
                                           "meter_id": m}) for m in scope_meters]
    return rows


def expand_plan(entry: Entry) -> list[tuple[str, dict]]:
    identity, rest = split(entry.values, PLAN_IDENTITY_COLUMNS)
    rows = [("plan", identity)]
    if "price_amount" not in rest:
        return rows
    allowances = rest.pop("allowances", [])
    clients = rest.pop("clients", [])
    rest["price_amount"] = decimal_text(entry, rest["price_amount"])
    _, revision = versioned(entry, "plan_revision",
                            {"plan_id": identity["plan_id"], **rest})
    revision_id = revision["plan_revision_id"]
    rows.append(("plan_revision", revision))
    rows += [("plan_allowance", {"plan_revision_id": revision_id, **allowance})
             for allowance in allowances]
    rows += [("plan_revision_client", {"plan_revision_id": revision_id,
                                       "client_id": client}) for client in clients]
    return rows


def expand_model_revision(entry: Entry) -> list[tuple[str, dict]]:
    values = dict(entry.values)
    efforts = values.pop("efforts", [])
    default_effort = values.pop("default_effort", None)
    modalities = [("input", m) for m in values.pop("input_modalities", [])]
    modalities += [("output", m) for m in values.pop("output_modalities", [])]
    _, revision = versioned(entry, "model_revision", values)
    revision_id = revision["model_revision_id"]
    rows = [("model_revision", revision)]
    rows += [("model_revision_effort", {"model_revision_id": revision_id,
                                        "effort": effort,
                                        "is_default": int(effort == default_effort)})
             for effort in efforts]
    rows += [("model_revision_modality", {"model_revision_id": revision_id,
                                          "direction": direction, "modality": modality})
             for direction, modality in modalities]
    return rows


def expand_offering(entry: Entry) -> list[tuple[str, dict]]:
    identity, rest = split(entry.values, OFFERING_IDENTITY_COLUMNS)
    identity.setdefault("variant", "")
    identity.setdefault("offering_id", keys.offering_id(
        identity["channel_id"], identity["model_id"], identity["variant"]))
    rows = [("offering", identity)]
    if rest:
        rows.append(versioned(entry, "offering_revision",
                              {"offering_id": identity["offering_id"], **rest}))
    return rows


def namespaced(table: str):
    def handler(entry: Entry) -> list[tuple[str, dict]]:
        values = dict(entry.values)
        channel, client = values.pop("channel", None), values.pop("client", None)
        if (channel is None) == (client is None):
            raise EntryError(f"{entry.origin}：{table} 必须且只能指定 channel 或 client")
        kind, member = ("channel", channel) if channel else ("client", client)
        namespace = {"namespace_id": f"{kind}:{member}", "kind": kind,
                     f"{kind}_id": member}
        values["namespace_id"] = namespace["namespace_id"]
        return [("label_namespace", namespace), versioned(entry, table, values)]
    return handler


def expand_supersede(entry: Entry) -> list[tuple[str, dict]]:
    values = dict(entry.values)
    table = values.pop("table")
    if table == "price_card" and "key" not in values:
        values["key"] = price_series_of(entry, values)["price_series_id"]
    target = keys.surrogate_id(table, values["key"], values["valid_from"],
                               values["recorded_at"])
    return [("__supersede__", {"table": table, "row_id": target,
                               "superseded_at": values["superseded_at"],
                               "supersede_reason": values["reason"]})]


HANDLERS = {
    "price_card": expand_price_card,
    "unit_rate": expand_unit_rate,
    "pricing_rule": expand_pricing_rule,
    "plan": expand_plan,
    "model_revision": expand_model_revision,
    "offering": expand_offering,
    "model_alias": namespaced("model_alias"),
    "price_gap": namespaced("price_gap"),
    "supersede": expand_supersede,
}
