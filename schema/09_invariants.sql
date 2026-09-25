CREATE VIEW v_scd2_overlap AS
WITH spans AS (
  SELECT 'price_card' AS tbl, price_card_id AS row_id, price_series_id AS durable_key,
         valid_from, valid_to, recorded_at, superseded_at
    FROM price_card
  UNION ALL
  SELECT 'model_revision', model_revision_id, model_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM model_revision
  UNION ALL
  SELECT 'client_revision', client_revision_id, client_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM client_revision
  UNION ALL
  SELECT 'model_identifier', model_identifier_id,
         namespace_id || '|' || kind || '|' || identifier,
         valid_from, valid_to, recorded_at, superseded_at
    FROM model_identifier
  UNION ALL
  SELECT 'offering_revision', offering_revision_id, offering_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM offering_revision
  UNION ALL
  SELECT 'offering_route', offering_route_id,
         offering_id || '|' || upstream_offering_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM offering_route
  UNION ALL
  SELECT 'plan_revision', plan_revision_id, plan_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM plan_revision
  UNION ALL
  SELECT 'unit_rate', unit_rate_id, unit_rate_series_id,
         valid_from, valid_to, recorded_at, superseded_at
    FROM unit_rate
  UNION ALL
  SELECT 'pricing_rule_revision', pricing_rule_revision_id, rule_key,
         valid_from, valid_to, recorded_at, superseded_at
    FROM pricing_rule_revision
  UNION ALL
  SELECT 'price_gap', price_gap_id, namespace_id || '|' || coalesce(label, ''),
         valid_from, valid_to, recorded_at, superseded_at
    FROM price_gap
)
SELECT a.tbl, a.durable_key, a.row_id AS row_a, b.row_id AS row_b
  FROM spans a
  JOIN spans b
    ON a.tbl = b.tbl AND a.durable_key = b.durable_key AND a.row_id < b.row_id
 WHERE a.valid_from < coalesce(b.valid_to, '9999-12-31T00:00:00Z')
   AND b.valid_from < coalesce(a.valid_to, '9999-12-31T00:00:00Z')
   AND a.recorded_at < coalesce(b.superseded_at, '9999-12-31T00:00:00Z')
   AND b.recorded_at < coalesce(a.superseded_at, '9999-12-31T00:00:00Z');

CREATE VIEW v_context_tier_mismatch AS
SELECT c.price_card_id
  FROM price_card c
 WHERE (c.context_tier_bound IS NOT NULL)
    <> EXISTS (SELECT 1 FROM price_rate r
                WHERE r.price_card_id = c.price_card_id AND r.context_min_tokens > 0);

CREATE VIEW v_card_without_base_rate AS
SELECT c.price_card_id
  FROM price_card c
 WHERE NOT EXISTS (SELECT 1 FROM price_rate r
                    WHERE r.price_card_id = c.price_card_id
                      AND r.context_min_tokens = 0);

CREATE VIEW v_route_within_channel AS
SELECT r.offering_route_id, r.offering_id, r.upstream_offering_id
  FROM offering_route r
  JOIN offering o ON o.offering_id = r.offering_id
  JOIN offering u ON u.offering_id = r.upstream_offering_id
 WHERE o.channel_id = u.channel_id;

CREATE VIEW v_card_upstream_without_route AS
SELECT c.price_card_id, s.offering_id, s.upstream_offering_id
  FROM price_card c
  JOIN price_series s ON s.price_series_id = c.price_series_id
 WHERE s.upstream_offering_id IS NOT NULL
   AND c.superseded_at IS NULL
   AND NOT EXISTS (
         SELECT 1 FROM offering_route r
          WHERE r.offering_id = s.offering_id
            AND r.upstream_offering_id = s.upstream_offering_id
            AND r.superseded_at IS NULL
            AND r.valid_from <= c.valid_from
            AND (r.valid_to IS NULL OR c.valid_from < r.valid_to));

CREATE VIEW v_derived_card_rule_mismatch AS
SELECT c.price_card_id
  FROM price_card c
  JOIN price_series s ON s.price_series_id = c.price_series_id
  JOIN pricing_rule_revision v
    ON v.pricing_rule_revision_id = c.derived_from_rule_revision_id
  JOIN pricing_rule r ON r.rule_key = v.rule_key
 WHERE r.channel_id <> s.channel_id;

CREATE VIEW v_relative_rate_in_fiat AS
SELECT r.price_card_id, r.meter_id
  FROM price_rate r
  JOIN meter m ON m.meter_id = r.meter_id
  JOIN price_card c ON c.price_card_id = r.price_card_id
  JOIN price_series s ON s.price_series_id = c.price_series_id
  JOIN billing_unit u ON u.unit_id = s.price_unit_id
 WHERE m.quantity_unit = 'relative' AND u.kind = 'fiat';

CREATE VIEW v_primary_evidence_mismatch AS
SELECT e.price_card_id, e.source_id, e.stance
  FROM price_evidence e
  JOIN price_card c ON c.price_card_id = e.price_card_id
 WHERE (e.stance = 'primary') <> (e.source_id = c.source_id);

CREATE VIEW v_router_outside_owner AS
SELECT o.offering_id
  FROM offering o
  JOIN model m ON m.model_id = o.model_id
  JOIN channel ch ON ch.channel_id = o.channel_id
 WHERE m.kind = 'router' AND ch.owner_org_id <> m.vendor_org_id;

CREATE VIEW v_identifier_offering_mismatch AS
SELECT i.model_identifier_id, i.namespace_id, i.identifier, i.offering_id
  FROM model_identifier i
  JOIN label_namespace n ON n.namespace_id = i.namespace_id
  JOIN offering o ON o.offering_id = i.offering_id
 WHERE n.channel_id IS NULL OR o.channel_id <> n.channel_id OR o.model_id <> i.model_id;

CREATE VIEW v_identifier_ambiguous AS
SELECT a.namespace_id, a.identifier,
       a.model_identifier_id AS first_row, b.model_identifier_id AS second_row
  FROM model_identifier a
  JOIN model_identifier b
    ON b.namespace_id = a.namespace_id AND b.identifier = a.identifier
   AND b.model_identifier_id > a.model_identifier_id
 WHERE (a.model_id <> b.model_id OR a.offering_id IS NOT b.offering_id)
   AND a.valid_from < coalesce(b.valid_to, '9999-12-31T00:00:00Z')
   AND b.valid_from < coalesce(a.valid_to, '9999-12-31T00:00:00Z')
   AND a.recorded_at < coalesce(b.superseded_at, '9999-12-31T00:00:00Z')
   AND b.recorded_at < coalesce(a.superseded_at, '9999-12-31T00:00:00Z');
