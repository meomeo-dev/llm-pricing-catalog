CREATE TABLE model (
  model_id         TEXT PRIMARY KEY,
  vendor_org_id    TEXT NOT NULL REFERENCES organization,
  kind             TEXT NOT NULL DEFAULT 'vendor_model' CHECK (kind IN (
                     'vendor_model', 'router')),
  family           TEXT,
  display_name     TEXT NOT NULL
) STRICT;

CREATE TABLE model_revision (
  model_revision_id INTEGER PRIMARY KEY,
  model_id         TEXT NOT NULL REFERENCES model,
  lifecycle        TEXT NOT NULL CHECK (lifecycle IN (
                     'preview', 'ga', 'limited', 'deprecated', 'retired')),
  released_on      TEXT CHECK (released_on GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  deprecated_on    TEXT CHECK (deprecated_on GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  retires_on       TEXT CHECK (retires_on GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  context_window   INTEGER CHECK (context_window > 0),
  max_input_tokens INTEGER CHECK (max_input_tokens > 0),
  max_output_tokens INTEGER CHECK (max_output_tokens > 0),
  knowledge_cutoff TEXT CHECK (knowledge_cutoff GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]'
                     OR knowledge_cutoff GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  training_cutoff  TEXT CHECK (training_cutoff GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]'
                     OR training_cutoff GLOB '[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]'),
  reasoning        TEXT CHECK (reasoning IN ('none', 'optional', 'always')),
  tokenizer        TEXT,
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

CREATE TABLE model_revision_modality (
  model_revision_id INTEGER NOT NULL REFERENCES model_revision,
  direction        TEXT NOT NULL CHECK (direction IN ('input', 'output')),
  modality         TEXT NOT NULL CHECK (modality IN (
                     'text', 'image', 'audio', 'video', 'file')),
  PRIMARY KEY (model_revision_id, direction, modality)
) STRICT;

CREATE TABLE model_revision_effort (
  model_revision_id INTEGER NOT NULL REFERENCES model_revision,
  effort           TEXT NOT NULL,
  is_default       INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
  PRIMARY KEY (model_revision_id, effort)
) STRICT;
CREATE UNIQUE INDEX one_default_effort_per_revision
  ON model_revision_effort (model_revision_id) WHERE is_default = 1;

CREATE TABLE client_revision (
  client_revision_id INTEGER PRIMARY KEY,
  client_id        TEXT NOT NULL REFERENCES client,
  reference_channel_id TEXT REFERENCES channel,
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

CREATE TABLE offering (
  offering_id      TEXT PRIMARY KEY,
  channel_id       TEXT NOT NULL REFERENCES channel,
  model_id         TEXT NOT NULL REFERENCES model,
  variant          TEXT NOT NULL DEFAULT '',
  UNIQUE (channel_id, model_id, variant),
  UNIQUE (offering_id, channel_id),
  CHECK (offering_id = channel_id || '/' || model_id
         || CASE WHEN variant = '' THEN '' ELSE '@' || variant END)
) STRICT;

CREATE TABLE model_identifier (
  model_identifier_id INTEGER PRIMARY KEY,
  namespace_id     TEXT NOT NULL REFERENCES label_namespace,
  kind             TEXT NOT NULL CHECK (kind IN ('api_id', 'display_name', 'label')),
  identifier       TEXT NOT NULL CHECK (identifier <> ''),
  identifier_key   TEXT GENERATED ALWAYS AS (lower(replace(replace(replace(
                     identifier, ' ', '-'), '_', '-'), '.', '-'))) VIRTUAL,
  model_id         TEXT NOT NULL REFERENCES model,
  offering_id      TEXT REFERENCES offering,
  implied_effort   TEXT,
  implied_variant  TEXT,
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

CREATE TABLE offering_revision (
  offering_revision_id INTEGER PRIMARY KEY,
  offering_id      TEXT NOT NULL REFERENCES offering,
  api_surface      TEXT,
  availability     TEXT NOT NULL CHECK (availability IN (
                     'available', 'limited', 'extended_access', 'retired')),
  operator_org_id  TEXT REFERENCES organization,
  seller_org_id    TEXT REFERENCES organization,
  billing_org_id   TEXT REFERENCES organization,
  vendor_relationship TEXT NOT NULL CHECK (vendor_relationship IN (
                     'first_party', 'contracted_partner', 'disclosed_reseller',
                     'self_declared_official', 'account_pool', 'unknown')),
  discloses_upstream INTEGER NOT NULL DEFAULT 0 CHECK (discloses_upstream IN (0, 1)),
  context_window   INTEGER CHECK (context_window > 0),
  max_output_tokens INTEGER CHECK (max_output_tokens > 0),
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

CREATE TABLE offering_route (
  offering_route_id INTEGER PRIMARY KEY,
  offering_id      TEXT NOT NULL REFERENCES offering,
  upstream_offering_id TEXT NOT NULL REFERENCES offering,
  routing          TEXT NOT NULL CHECK (routing IN (
                     'sole', 'load_balanced', 'fallback')),
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
  CHECK (offering_id <> upstream_offering_id)
) STRICT;
