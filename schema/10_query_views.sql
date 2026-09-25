CREATE VIEW price_history AS
SELECT o.model_id,
       mo.display_name AS model_name,
       o.channel_id,
       ch.display_name AS channel_name,
       o.variant,
       s.service_tier,
       s.region_id,
       s.plan_id,
       s.window_id,
       s.commitment_term,
       s.upstream_offering_id,
       r.meter_id,
       r.context_min_tokens,
       c.context_tier_bound,
       r.amount,
       r.amount_value,
       s.price_unit_id,
       m.per_quantity,
       m.quantity_unit,
       c.is_promotional,
       c.derivation,
       c.valid_from,
       c.valid_to,
       c.date_basis,
       c.source_id,
       src.url AS source_url,
       src.retrieved_at AS source_retrieved_at,
       c.price_card_id,
       s.price_series_id
  FROM price_rate r
  JOIN price_card c ON c.price_card_id = r.price_card_id
  JOIN price_series s ON s.price_series_id = c.price_series_id
  JOIN offering o ON o.offering_id = s.offering_id
  JOIN model mo ON mo.model_id = o.model_id
  JOIN channel ch ON ch.channel_id = o.channel_id
  JOIN meter m ON m.meter_id = r.meter_id
  JOIN source src ON src.source_id = c.source_id
 WHERE c.superseded_at IS NULL;

CREATE VIEW price_current AS
SELECT *
  FROM price_history
 WHERE valid_from <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
   AND (valid_to IS NULL OR strftime('%Y-%m-%dT%H:%M:%SZ', 'now') < valid_to);

CREATE VIEW model_identifier_lookup AS
SELECT i.identifier, i.identifier_key, i.kind, i.namespace_id, n.kind AS namespace_kind,
       n.channel_id, n.client_id, i.model_id, i.offering_id, i.implied_effort,
       i.implied_variant, i.valid_from, i.valid_to, i.date_basis, i.source_id
  FROM model_identifier i
  JOIN label_namespace n ON n.namespace_id = i.namespace_id
 WHERE i.superseded_at IS NULL
UNION ALL
SELECT m.model_id,
       lower(replace(replace(replace(m.model_id, ' ', '-'), '_', '-'), '.', '-')),
       'model_id', NULL, 'catalog', NULL, NULL, m.model_id, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL
  FROM model m
UNION ALL
SELECT m.display_name,
       lower(replace(replace(replace(m.display_name, ' ', '-'), '_', '-'), '.', '-')),
       'display_name', NULL, 'catalog', NULL, NULL, m.model_id, NULL, NULL, NULL,
       NULL, NULL, NULL, NULL
  FROM model m;

CREATE VIEW model_identifier_current AS
SELECT *
  FROM model_identifier_lookup
 WHERE (valid_from IS NULL OR valid_from <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
   AND (valid_to IS NULL OR strftime('%Y-%m-%dT%H:%M:%SZ', 'now') < valid_to);
