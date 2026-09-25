CREATE TABLE plan (
  plan_id          TEXT PRIMARY KEY,
  channel_id       TEXT NOT NULL REFERENCES channel,
  display_name     TEXT NOT NULL,
  UNIQUE (plan_id, channel_id)
) STRICT;

CREATE TABLE plan_revision (
  plan_revision_id INTEGER PRIMARY KEY,
  plan_id          TEXT NOT NULL REFERENCES plan,
  price_amount     TEXT NOT NULL CHECK (price_amount GLOB '[0-9]*'
                     AND price_amount NOT GLOB '*[^0-9.]*'
                     AND price_amount NOT GLOB '*.*.*' AND price_amount NOT GLOB '*.'),
  price_unit_id    TEXT NOT NULL REFERENCES billing_unit,
  billing_period   TEXT NOT NULL CHECK (billing_period IN (
                     'month', 'year', 'one_time', 'none')),
  usage_limit_text TEXT,
  valid_from       TEXT NOT NULL CHECK (valid_from GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  valid_to         TEXT CHECK (valid_to GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  date_basis       TEXT NOT NULL CHECK (date_basis IN (
                     'official_effective', 'official_announced', 'first_observed',
                     'inferred')),
  recorded_at      TEXT NOT NULL CHECK (recorded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  superseded_at    TEXT CHECK (superseded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  supersede_reason TEXT CHECK (supersede_reason IN (
                     'correction', 'cancelled', 'restated')),
  source_id        TEXT NOT NULL REFERENCES source,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  CHECK (superseded_at IS NULL OR superseded_at > recorded_at),
  CHECK ((superseded_at IS NULL) = (supersede_reason IS NULL))
) STRICT;

CREATE TABLE plan_revision_client (
  plan_revision_id INTEGER NOT NULL REFERENCES plan_revision,
  client_id        TEXT NOT NULL REFERENCES client,
  PRIMARY KEY (plan_revision_id, client_id)
) STRICT;

CREATE TABLE plan_allowance (
  plan_revision_id INTEGER NOT NULL REFERENCES plan_revision,
  pool             TEXT NOT NULL DEFAULT 'default',
  unit_id          TEXT NOT NULL REFERENCES billing_unit,
  refresh_window   TEXT NOT NULL CHECK (refresh_window IN (
                     '5h', 'day', 'week', 'month', 'year', 'none')),
  quantity         TEXT CHECK (quantity GLOB '[0-9]*'
                     AND quantity NOT GLOB '*[^0-9.]*'
                     AND quantity NOT GLOB '*.*.*' AND quantity NOT GLOB '*.'),
  expires_after    TEXT,
  notes            TEXT,
  PRIMARY KEY (plan_revision_id, pool, unit_id, refresh_window)
) STRICT;

CREATE TABLE unit_rate_series (
  unit_rate_series_id TEXT PRIMARY KEY,
  unit_id          TEXT NOT NULL REFERENCES billing_unit,
  value_unit_id    TEXT NOT NULL REFERENCES billing_unit,
  rate_kind        TEXT NOT NULL CHECK (rate_kind IN (
                     'list', 'included', 'overage', 'top_up')),
  region_id        TEXT NOT NULL DEFAULT 'global' REFERENCES region,
  channel_id       TEXT REFERENCES channel,
  plan_id          TEXT,
  min_purchase     TEXT CHECK (min_purchase GLOB '[0-9]*'
                     AND min_purchase NOT GLOB '*[^0-9.]*'
                     AND min_purchase NOT GLOB '*.*.*' AND min_purchase NOT GLOB '*.'),
  FOREIGN KEY (plan_id, channel_id) REFERENCES plan (plan_id, channel_id),
  CHECK (plan_id IS NULL OR channel_id IS NOT NULL),
  CHECK (unit_id <> value_unit_id),
  CHECK (unit_rate_series_id = unit_id || '>' || value_unit_id || '/' || rate_kind
         || '/' || region_id || coalesce('/channel:' || channel_id, '')
         || coalesce('/plan:' || plan_id, '') || coalesce('/min:' || min_purchase, ''))
) STRICT;

CREATE TABLE unit_rate (
  unit_rate_id     INTEGER PRIMARY KEY,
  unit_rate_series_id TEXT NOT NULL REFERENCES unit_rate_series,
  value_amount     TEXT NOT NULL CHECK (value_amount GLOB '[0-9]*'
                     AND value_amount NOT GLOB '*[^0-9.]*'
                     AND value_amount NOT GLOB '*.*.*' AND value_amount NOT GLOB '*.'),
  derivation       TEXT NOT NULL DEFAULT 'published' CHECK (derivation IN (
                     'published', 'derived_from_plan')),
  notes            TEXT,
  valid_from       TEXT NOT NULL CHECK (valid_from GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  valid_to         TEXT CHECK (valid_to GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  date_basis       TEXT NOT NULL CHECK (date_basis IN (
                     'official_effective', 'official_announced', 'first_observed',
                     'inferred')),
  recorded_at      TEXT NOT NULL CHECK (recorded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  superseded_at    TEXT CHECK (superseded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  supersede_reason TEXT CHECK (supersede_reason IN (
                     'correction', 'cancelled', 'restated')),
  source_id        TEXT NOT NULL REFERENCES source,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  CHECK (superseded_at IS NULL OR superseded_at > recorded_at),
  CHECK ((superseded_at IS NULL) = (supersede_reason IS NULL))
) STRICT;

CREATE TABLE pricing_rule (
  rule_key         TEXT PRIMARY KEY,
  channel_id       TEXT NOT NULL REFERENCES channel,
  plan_id          TEXT,
  kind             TEXT NOT NULL CHECK (kind IN (
                     'markup', 'discount', 'additive', 'usage_fee', 'byok_fee')),
  reference_channel_id TEXT REFERENCES channel,
  FOREIGN KEY (plan_id, channel_id) REFERENCES plan (plan_id, channel_id)
) STRICT;

CREATE TABLE pricing_rule_revision (
  pricing_rule_revision_id INTEGER PRIMARY KEY,
  rule_key         TEXT NOT NULL REFERENCES pricing_rule,
  factor           TEXT CHECK (factor GLOB '[0-9]*'
                     AND factor NOT GLOB '*[^0-9.]*'
                     AND factor NOT GLOB '*.*.*' AND factor NOT GLOB '*.'),
  addend           TEXT CHECK (addend GLOB '[0-9]*'
                     AND addend NOT GLOB '*[^0-9.]*'
                     AND addend NOT GLOB '*.*.*' AND addend NOT GLOB '*.'),
  addend_unit_id   TEXT REFERENCES billing_unit,
  addend_meter_id  TEXT REFERENCES meter,
  free_allowance   TEXT CHECK (free_allowance GLOB '[0-9]*'
                     AND free_allowance NOT GLOB '*[^0-9.]*'
                     AND free_allowance NOT GLOB '*.*.*' AND free_allowance NOT GLOB '*.'),
  notes            TEXT,
  valid_from       TEXT NOT NULL CHECK (valid_from GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  valid_to         TEXT CHECK (valid_to GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  date_basis       TEXT NOT NULL CHECK (date_basis IN (
                     'official_effective', 'official_announced', 'first_observed',
                     'inferred')),
  recorded_at      TEXT NOT NULL CHECK (recorded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  superseded_at    TEXT CHECK (superseded_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  supersede_reason TEXT CHECK (supersede_reason IN (
                     'correction', 'cancelled', 'restated')),
  source_id        TEXT NOT NULL REFERENCES source,
  CHECK (valid_to IS NULL OR valid_to > valid_from),
  CHECK (superseded_at IS NULL OR superseded_at > recorded_at),
  CHECK ((superseded_at IS NULL) = (supersede_reason IS NULL)),
  CHECK (factor IS NOT NULL OR addend IS NOT NULL),
  CHECK ((addend IS NULL) = (addend_unit_id IS NULL)),
  CHECK ((addend IS NULL) = (addend_meter_id IS NULL))
) STRICT;

CREATE TABLE pricing_rule_scope_model (
  pricing_rule_revision_id INTEGER NOT NULL REFERENCES pricing_rule_revision,
  model_id         TEXT NOT NULL REFERENCES model,
  PRIMARY KEY (pricing_rule_revision_id, model_id)
) STRICT;

CREATE TABLE pricing_rule_scope_meter (
  pricing_rule_revision_id INTEGER NOT NULL REFERENCES pricing_rule_revision,
  meter_id         TEXT NOT NULL REFERENCES meter,
  PRIMARY KEY (pricing_rule_revision_id, meter_id)
) STRICT;
