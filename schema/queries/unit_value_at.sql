WITH RECURSIVE
known AS (
  SELECT coalesce(:known_at, '9999-12-31T00:00:00Z') AS t
),
hop AS (
  SELECT u.unit_rate_id, u.value_amount, s.unit_id, s.value_unit_id, s.rate_kind
    FROM unit_rate u
    JOIN unit_rate_series s ON s.unit_rate_series_id = u.unit_rate_series_id, known
   WHERE u.valid_from <= :at AND (u.valid_to IS NULL OR :at < u.valid_to)
     AND u.recorded_at <= known.t
     AND (u.superseded_at IS NULL OR u.superseded_at > known.t)
     AND (s.channel_id IS NULL OR s.channel_id = :channel_id)
     AND (s.plan_id IS NULL OR s.plan_id = :plan_id)
     AND s.region_id = coalesce(:region_id, 'global')
),
path (unit_id, value, depth, rate_kinds, unit_rate_ids) AS (
  SELECT :unit_id, 1.0, 0, '', ''
  UNION ALL
  SELECT hop.value_unit_id,
         path.value * CAST(hop.value_amount AS REAL),
         path.depth + 1,
         path.rate_kinds || CASE WHEN path.depth = 0 THEN '' ELSE ' > ' END
           || hop.rate_kind,
         path.unit_rate_ids || CASE WHEN path.depth = 0 THEN '' ELSE ',' END
           || hop.unit_rate_id
    FROM path
    JOIN hop ON hop.unit_id = path.unit_id
   WHERE path.depth < 4
)
SELECT value, depth, rate_kinds, unit_rate_ids
  FROM path
 WHERE unit_id = :target_unit_id AND depth > 0
 ORDER BY depth, rate_kinds;
