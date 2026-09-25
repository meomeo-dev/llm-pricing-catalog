INSERT INTO organization VALUES
  ('anthropic', 'Anthropic', 'https://www.anthropic.com'),
  ('openai', 'OpenAI', 'https://openai.com'),
  ('google', 'Google', 'https://ai.google.dev'),
  ('deepseek', 'DeepSeek', 'https://www.deepseek.com'),
  ('fixture', '构造数据', NULL);

INSERT INTO channel VALUES
  ('anthropic-api', 'anthropic', 'first_party_api', 'Claude API',
   'https://platform.claude.com/docs/en/about-claude/pricing'),
  ('openai-api', 'openai', 'first_party_api', 'OpenAI API',
   'https://developers.openai.com/api/docs/pricing'),
  ('gemini-api', 'google', 'first_party_api', 'Gemini Developer API',
   'https://ai.google.dev/gemini-api/docs/pricing'),
  ('deepseek-api', 'deepseek', 'first_party_api', 'DeepSeek API',
   'https://api-docs.deepseek.com/quick_start/pricing');

INSERT INTO client VALUES ('agy', 'Antigravity CLI', NULL);
INSERT INTO label_namespace (namespace_id, kind, client_id) VALUES
  ('client:agy', 'client', 'agy');

INSERT INTO billing_unit VALUES
  ('USD', 'fiat', NULL, '美元'),
  ('CNY', 'fiat', NULL, '人民币');

INSERT INTO meter VALUES
  ('input', 'token', 1000000, '输入 token（未命中缓存）'),
  ('cache_read', 'token', 1000000, '缓存命中读取'),
  ('cache_write_5m', 'token', 1000000, '缓存写入，5 分钟 TTL'),
  ('cache_write_1h', 'token', 1000000, '缓存写入，1 小时 TTL'),
  ('cache_write', 'token', 1000000, '缓存写入，未区分 TTL'),
  ('output', 'token', 1000000, '输出 token，含推理 token');

INSERT INTO source (source_id, url, publisher_org_id, kind, retrieved_at,
  page_updated_on)
VALUES
  ('anthropic-pricing@2026-09-24',
   'https://platform.claude.com/docs/en/about-claude/pricing', 'anthropic',
   'official_pricing_page', '2026-09-24T20:43:00Z', NULL),
  ('openai-pricing@2026-09-24', 'https://developers.openai.com/api/docs/pricing',
   'openai', 'official_pricing_page', '2026-09-24T20:41:00Z', NULL),
  ('gemini-pricing@2026-09-24', 'https://ai.google.dev/gemini-api/docs/pricing',
   'google', 'official_pricing_page', '2026-09-24T20:41:00Z', '2026-09-24'),
  ('deepseek-pricing@2026-09-24',
   'https://api-docs.deepseek.com/quick_start/pricing', 'deepseek',
   'official_pricing_page', '2026-09-24T20:45:00Z', NULL),
  ('fixture-constructed', 'about:blank', 'fixture', 'constructed',
   '2026-06-30T00:00:00Z', NULL);

INSERT INTO client_revision (client_revision_id, client_id, reference_channel_id,
  valid_from, date_basis, recorded_at, source_id)
VALUES (101, 'agy', 'gemini-api', '2026-01-01T00:00:00Z', 'inferred',
  '2026-09-24T00:00:00Z', 'fixture-constructed');

INSERT INTO model (model_id, vendor_org_id, family, display_name) VALUES
  ('claude-opus-5-5', 'anthropic', 'claude-opus', 'Claude Opus 5.5'),
  ('claude-sonnet-5', 'anthropic', 'claude-sonnet', 'Claude Sonnet 5'),
  ('gpt-6-sol', 'openai', 'gpt-6', 'GPT-6 Sol'),
  ('gemini-3.8-flash', 'google', 'gemini-flash', 'Gemini 3.8 Flash'),
  ('deepseek-v4-pro', 'deepseek', 'deepseek-v4', 'DeepSeek V4 Pro');

INSERT INTO offering (offering_id, channel_id, model_id) VALUES
  ('anthropic-api/claude-opus-5-5', 'anthropic-api', 'claude-opus-5-5'),
  ('anthropic-api/claude-sonnet-5', 'anthropic-api', 'claude-sonnet-5'),
  ('openai-api/gpt-6-sol', 'openai-api', 'gpt-6-sol'),
  ('gemini-api/gemini-3.8-flash', 'gemini-api', 'gemini-3.8-flash'),
  ('deepseek-api/deepseek-v4-pro', 'deepseek-api', 'deepseek-v4-pro');

INSERT INTO time_window VALUES
  ('deepseek-peak', 'UTC', '[1,2,3,4,5]', '[["01:00","04:00"],["06:00","10:00"]]',
   'CN', 'DeepSeek 高峰时段（英文价目页口径）');

INSERT INTO model_revision (model_revision_id, model_id, lifecycle, context_window,
  max_output_tokens, knowledge_cutoff, reasoning, valid_from, date_basis, recorded_at,
  source_id)
VALUES (101, 'gpt-6-sol', 'ga', 1050000, 128000, '2026-04-20', 'optional',
  '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T20:41:00Z',
  'openai-pricing@2026-09-24');
INSERT INTO model_revision_effort (model_revision_id, effort) VALUES
  (101, 'none'), (101, 'low'), (101, 'medium'), (101, 'high'), (101, 'xhigh'),
  (101, 'max');

INSERT INTO model_alias (namespace_id, alias, model_id, implied_effort, valid_from,
  date_basis, recorded_at, source_id)
VALUES ('client:agy', 'gemini-3.8-flash-high', 'gemini-3.8-flash', 'high',
  '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T00:00:00Z',
  'fixture-constructed');

INSERT INTO price_series (price_series_id, channel_id, offering_id, price_unit_id,
  window_id)
VALUES
  ('anthropic-api/claude-opus-5-5/standard/global/USD', 'anthropic-api',
   'anthropic-api/claude-opus-5-5', 'USD', NULL),
  ('openai-api/gpt-6-sol/standard/global/USD', 'openai-api', 'openai-api/gpt-6-sol',
   'USD', NULL),
  ('gemini-api/gemini-3.8-flash/standard/global/USD', 'gemini-api',
   'gemini-api/gemini-3.8-flash', 'USD', NULL),
  ('anthropic-api/claude-sonnet-5/standard/global/USD', 'anthropic-api',
   'anthropic-api/claude-sonnet-5', 'USD', NULL),
  ('deepseek-api/deepseek-v4-pro/standard/global/USD', 'deepseek-api',
   'deepseek-api/deepseek-v4-pro', 'USD', NULL),
  ('deepseek-api/deepseek-v4-pro/standard/global/USD/window:deepseek-peak',
   'deepseek-api', 'deepseek-api/deepseek-v4-pro', 'USD', 'deepseek-peak');

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES (101, 'anthropic-api/claude-opus-5-5/standard/global/USD',
  '2026-09-21T00:00:00Z', 'first_observed', '2026-09-24T20:43:00Z',
  'anthropic-pricing@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (101, 'input', '4'), (101, 'cache_write_5m', '5'), (101, 'cache_write_1h', '8'),
  (101, 'cache_read', '0.20'), (101, 'output', '20');
INSERT INTO price_evidence (price_card_id, source_id, stance, excerpt) VALUES
  (101, 'anthropic-pricing@2026-09-24', 'primary',
   'Claude Opus 5.5 | $4 / MTok | $5 / MTok | $8 / MTok | $0.20 / MTok | $20 / MTok');

INSERT INTO price_card (price_card_id, price_series_id, context_tier_bound,
  valid_from, date_basis, recorded_at, source_id)
VALUES (102, 'openai-api/gpt-6-sol/standard/global/USD', 'gt',
  '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T20:41:00Z',
  'openai-pricing@2026-09-24');
INSERT INTO price_rate VALUES
  (102, 'input', 0, '2.00'), (102, 'cache_read', 0, '0.20'),
  (102, 'cache_write', 0, '2.50'), (102, 'output', 0, '10.00'),
  (102, 'input', 272000, '4.00'), (102, 'cache_read', 272000, '0.40'),
  (102, 'cache_write', 272000, '5.00'), (102, 'output', 272000, '15.00');

INSERT INTO price_card (price_card_id, price_series_id, is_promotional, valid_from,
  valid_to, date_basis, recorded_at, source_id)
VALUES
  (103, 'gemini-api/gemini-3.8-flash/standard/global/USD', 1, '2026-09-01T00:00:00Z',
   '2027-01-01T00:00:00Z', 'official_effective', '2026-09-24T20:41:00Z',
   'gemini-pricing@2026-09-24'),
  (104, 'gemini-api/gemini-3.8-flash/standard/global/USD', 0, '2027-01-01T00:00:00Z',
   NULL, 'official_announced', '2026-09-24T20:41:00Z', 'gemini-pricing@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (103, 'input', '0.75'), (103, 'output', '3.75'),
  (104, 'input', '1.50'), (104, 'output', '7.50');

INSERT INTO price_card (price_card_id, price_series_id, is_promotional, valid_from,
  valid_to, date_basis, recorded_at, superseded_at, supersede_reason, source_id)
VALUES
  (105, 'anthropic-api/claude-sonnet-5/standard/global/USD', 1,
   '2026-06-30T00:00:00Z', '2026-09-01T00:00:00Z', 'official_effective',
   '2026-06-30T00:00:00Z', '2026-08-20T00:00:00Z', 'restated', 'fixture-constructed'),
  (106, 'anthropic-api/claude-sonnet-5/standard/global/USD', 0,
   '2026-09-01T00:00:00Z', NULL, 'official_announced',
   '2026-06-30T00:00:00Z', '2026-08-20T00:00:00Z', 'cancelled', 'fixture-constructed'),
  (107, 'anthropic-api/claude-sonnet-5/standard/global/USD', 0,
   '2026-06-30T00:00:00Z', NULL, 'official_effective',
   '2026-08-20T00:00:00Z', NULL, NULL, 'anthropic-pricing@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (105, 'input', '2'), (105, 'output', '10'),
  (106, 'input', '3'), (106, 'output', '15'),
  (107, 'input', '2'), (107, 'output', '10');

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES
  (108, 'deepseek-api/deepseek-v4-pro/standard/global/USD', '2026-08-01T00:00:00Z',
   'first_observed', '2026-09-24T20:45:00Z', 'deepseek-pricing@2026-09-24'),
  (109, 'deepseek-api/deepseek-v4-pro/standard/global/USD/window:deepseek-peak',
   '2026-08-01T00:00:00Z', 'first_observed', '2026-09-24T20:45:00Z',
   'deepseek-pricing@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (108, 'input', '0.66'), (108, 'output', '1.98'),
  (109, 'input', '1.32'), (109, 'output', '3.96');

INSERT INTO price_gap (price_gap_id, namespace_id, label, reason, notes, valid_from,
  date_basis, recorded_at, source_id)
VALUES (101, 'client:agy', 'agy-model:1026', 'legacy_label',
  '旧版数字标签，无法唯一对应模型', '2026-09-06T00:00:00Z', 'first_observed',
  '2026-09-06T00:00:00Z', 'fixture-constructed');
