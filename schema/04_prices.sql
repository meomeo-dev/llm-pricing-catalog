CREATE TABLE price_series (
  price_series_id  TEXT PRIMARY KEY,
  channel_id       TEXT NOT NULL REFERENCES channel,
  offering_id      TEXT NOT NULL,
  service_tier     TEXT NOT NULL DEFAULT 'standard' CHECK (service_tier IN (
                     'free', 'standard', 'batch', 'flex', 'priority', 'fast',
                     'provisioned', 'reserved')),
  region_id        TEXT NOT NULL DEFAULT 'global' REFERENCES region,
  price_unit_id    TEXT NOT NULL REFERENCES billing_unit,
  window_id        TEXT REFERENCES time_window,
  plan_id          TEXT,
  upstream_offering_id TEXT REFERENCES offering,
  commitment_term  TEXT CHECK (commitment_term IN ('1w', '1m', '3m', '1y')),
  FOREIGN KEY (offering_id, channel_id) REFERENCES offering (offering_id, channel_id),
  FOREIGN KEY (plan_id, channel_id) REFERENCES plan (plan_id, channel_id),
  CHECK (upstream_offering_id IS NULL OR upstream_offering_id <> offering_id),
  CHECK (price_series_id = offering_id || '/' || service_tier || '/' || region_id
         || '/' || price_unit_id || coalesce('/window:' || window_id, '')
         || coalesce('/plan:' || plan_id, '')
         || coalesce('/via:' || upstream_offering_id, '')
         || coalesce('/term:' || commitment_term, ''))
) STRICT;

CREATE TABLE price_card (
  price_card_id    INTEGER PRIMARY KEY,
  price_series_id  TEXT NOT NULL REFERENCES price_series,
  context_tier_bound TEXT CHECK (context_tier_bound IN ('gt', 'gte')),
  is_promotional   INTEGER NOT NULL DEFAULT 0 CHECK (is_promotional IN (0, 1)),
  derivation       TEXT NOT NULL DEFAULT 'published' CHECK (derivation IN (
                     'published', 'computed_from_rule')),
  derived_from_rule_revision_id INTEGER REFERENCES pricing_rule_revision,
  derived_from_card_id INTEGER REFERENCES price_card,
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
  CHECK ((derivation = 'computed_from_rule')
         = (derived_from_rule_revision_id IS NOT NULL))
) STRICT;

CREATE TABLE price_rate (
  price_card_id    INTEGER NOT NULL REFERENCES price_card,
  meter_id         TEXT NOT NULL REFERENCES meter,
  context_min_tokens INTEGER NOT NULL DEFAULT 0 CHECK (context_min_tokens >= 0),
  amount           TEXT NOT NULL CHECK (amount GLOB '[0-9]*'
                     AND amount NOT GLOB '*[^0-9.]*'
                     AND amount NOT GLOB '*.*.*' AND amount NOT GLOB '*.'),
  amount_value     REAL GENERATED ALWAYS AS (CAST(amount AS REAL)) VIRTUAL,
  PRIMARY KEY (price_card_id, meter_id, context_min_tokens)
) STRICT;

CREATE TABLE price_evidence (
  price_card_id    INTEGER NOT NULL REFERENCES price_card,
  source_id        TEXT NOT NULL REFERENCES source,
  stance           TEXT NOT NULL CHECK (stance IN (
                     'primary', 'supports', 'contradicts')),
  excerpt          TEXT,
  notes            TEXT,
  PRIMARY KEY (price_card_id, source_id)
) STRICT;
CREATE UNIQUE INDEX one_primary_evidence_per_card
  ON price_evidence (price_card_id) WHERE stance = 'primary';

CREATE TABLE price_gap (
  price_gap_id     INTEGER PRIMARY KEY,
  namespace_id     TEXT NOT NULL REFERENCES label_namespace,
  label            TEXT,
  reason           TEXT NOT NULL CHECK (reason IN (
                     'public_price_unavailable', 'legacy_label', 'synthetic_model',
                     'model_unknown')),
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
