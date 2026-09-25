PRAGMA foreign_keys = ON;

CREATE TABLE organization (
  org_id           TEXT PRIMARY KEY,
  display_name     TEXT NOT NULL,
  homepage_url     TEXT
) STRICT;

CREATE TABLE region (
  region_id        TEXT PRIMARY KEY,
  kind             TEXT NOT NULL CHECK (kind IN (
                     'global', 'geo', 'data_zone', 'single_region', 'in_region')),
  description      TEXT NOT NULL
) STRICT;
INSERT INTO region VALUES ('global', 'global', '全球路由');

CREATE TABLE channel (
  channel_id       TEXT PRIMARY KEY,
  owner_org_id     TEXT NOT NULL REFERENCES organization,
  kind             TEXT NOT NULL CHECK (kind IN (
                     'first_party_api', 'first_party_subscription', 'cloud_partner',
                     'enterprise_platform', 'aggregator', 'relay', 'tool_bundle')),
  display_name     TEXT NOT NULL,
  pricing_url      TEXT
) STRICT;
CREATE UNIQUE INDEX one_first_party_api_per_owner
  ON channel (owner_org_id) WHERE kind = 'first_party_api';

CREATE TABLE client (
  client_id        TEXT PRIMARY KEY,
  display_name     TEXT NOT NULL,
  notes            TEXT
) STRICT;

CREATE TABLE label_namespace (
  namespace_id     TEXT PRIMARY KEY,
  kind             TEXT NOT NULL CHECK (kind IN ('channel', 'client')),
  channel_id       TEXT UNIQUE REFERENCES channel,
  client_id        TEXT UNIQUE REFERENCES client,
  CHECK ((kind = 'channel') = (channel_id IS NOT NULL)),
  CHECK ((kind = 'client') = (client_id IS NOT NULL)),
  CHECK (namespace_id = kind || ':' || coalesce(channel_id, client_id))
) STRICT;

CREATE TABLE billing_unit (
  unit_id          TEXT PRIMARY KEY,
  kind             TEXT NOT NULL CHECK (kind IN (
                     'fiat', 'platform_credit', 'tool_credit', 'request', 'quota')),
  issuer_org_id    TEXT REFERENCES organization,
  description      TEXT NOT NULL,
  CHECK ((kind = 'fiat') = (issuer_org_id IS NULL))
) STRICT;

CREATE TABLE meter (
  meter_id         TEXT PRIMARY KEY,
  quantity_unit    TEXT NOT NULL CHECK (quantity_unit IN (
                     'token', 'token_hour', 'request', 'message', 'relative', 'hour',
                     'session_hour', 'ptu_hour', 'gsu_month', 'image', 'minute',
                     'second', 'character', 'gb_day')),
  per_quantity     INTEGER NOT NULL CHECK (per_quantity > 0),
  description      TEXT NOT NULL
) STRICT;

CREATE TABLE source (
  source_id        TEXT PRIMARY KEY,
  url              TEXT NOT NULL,
  publisher_org_id TEXT NOT NULL REFERENCES organization,
  kind             TEXT NOT NULL CHECK (kind IN (
                     'official_pricing_page', 'official_model_page', 'official_api',
                     'official_repository', 'official_announcement', 'third_party',
                     'client_observed', 'constructed')),
  machine_readable INTEGER NOT NULL DEFAULT 0 CHECK (machine_readable IN (0, 1)),
  retrieved_at     TEXT NOT NULL CHECK (retrieved_at GLOB
                     '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z'),
  page_updated_on  TEXT CHECK (page_updated_on GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  content_sha256   TEXT CHECK (length(content_sha256) = 64),
  snapshot_path    TEXT,
  notes            TEXT
) STRICT;

CREATE TABLE time_window (
  window_id        TEXT PRIMARY KEY,
  time_zone        TEXT NOT NULL,
  iso_weekdays     TEXT NOT NULL CHECK (json_valid(iso_weekdays)),
  ranges           TEXT NOT NULL CHECK (json_valid(ranges)),
  holiday_calendar TEXT,
  description      TEXT
) STRICT;
