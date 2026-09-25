WITH
known AS (
  SELECT coalesce(:known_at, '9999-12-31T00:00:00Z') AS t
),
requested AS (
  SELECT coalesce(:channel_id,
                  (SELECT v.reference_channel_id
                     FROM client_revision v, known
                    WHERE v.client_id = :client_id
                      AND v.valid_from <= :at
                      AND (v.valid_to IS NULL OR :at < v.valid_to)
                      AND v.recorded_at <= known.t
                      AND (v.superseded_at IS NULL OR v.superseded_at > known.t)))
           AS channel_id
),
resolved AS (
  SELECT coalesce(
    (SELECT a.model_id
       FROM model_alias a
       JOIN label_namespace n ON n.namespace_id = a.namespace_id, known, requested
      WHERE a.alias = :label
        AND (n.client_id = :client_id OR n.channel_id = requested.channel_id
             OR (requested.channel_id IS NULL
                 AND n.channel_id IN (SELECT channel_id FROM channel
                                       WHERE kind = 'first_party_api')))
        AND a.valid_from <= :at AND (a.valid_to IS NULL OR :at < a.valid_to)
        AND a.recorded_at <= known.t
        AND (a.superseded_at IS NULL OR a.superseded_at > known.t)
      ORDER BY n.kind = 'channel'
      LIMIT 1),
    :label) AS model_id
),
target AS (
  SELECT coalesce(requested.channel_id,
                  (SELECT ch.channel_id
                     FROM channel ch JOIN model m ON m.vendor_org_id = ch.owner_org_id
                    WHERE m.model_id = resolved.model_id
                      AND ch.kind = 'first_party_api')) AS channel_id
    FROM requested, resolved
),
candidate AS (
  SELECT c.*, s.offering_id, s.price_unit_id, s.plan_id,
         RANK() OVER (ORDER BY s.plan_id IS NULL) AS preference
    FROM price_card c
    JOIN price_series s ON s.price_series_id = c.price_series_id
    JOIN offering o ON o.offering_id = s.offering_id
    JOIN resolved ON o.model_id = resolved.model_id
    JOIN target ON o.channel_id = target.channel_id
    JOIN known
   WHERE o.variant = coalesce(:variant, '')
     AND s.service_tier = :service_tier
     AND s.region_id = :region_id
     AND (:price_unit_id IS NULL OR s.price_unit_id = :price_unit_id)
     AND (s.plan_id IS NULL OR s.plan_id IS :plan_id)
     AND s.upstream_offering_id IS :upstream_offering_id
     AND s.commitment_term IS :commitment_term
     AND s.window_id IS :window_id
     AND c.valid_from <= :at AND (c.valid_to IS NULL OR :at < c.valid_to)
     AND c.recorded_at <= known.t
     AND (c.superseded_at IS NULL OR c.superseded_at > known.t)
),
card AS (
  SELECT * FROM candidate WHERE preference = 1
)
SELECT card.price_card_id,
       card.price_series_id,
       card.offering_id,
       resolved.model_id,
       r.meter_id,
       r.context_min_tokens,
       r.amount,
       card.price_unit_id,
       card.plan_id,
       card.is_promotional,
       card.derivation,
       card.derived_from_rule_revision_id,
       card.date_basis,
       card.source_id,
       e.excerpt AS source_excerpt
  FROM card
  JOIN resolved
  JOIN price_rate r ON r.price_card_id = card.price_card_id
  LEFT JOIN price_evidence e
    ON e.price_card_id = card.price_card_id AND e.stance = 'primary'
 WHERE r.context_min_tokens = (
         SELECT max(r2.context_min_tokens)
           FROM price_rate r2
          WHERE r2.price_card_id = card.price_card_id
            AND r2.meter_id = r.meter_id
            AND (r2.context_min_tokens = 0
                 OR (card.context_tier_bound = 'gt'
                     AND :input_tokens > r2.context_min_tokens)
                 OR (card.context_tier_bound = 'gte'
                     AND :input_tokens >= r2.context_min_tokens)))
 ORDER BY card.price_card_id, r.meter_id;
