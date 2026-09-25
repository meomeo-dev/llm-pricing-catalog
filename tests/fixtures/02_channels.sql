INSERT INTO organization VALUES
  ('aws', 'Amazon Web Services', 'https://aws.amazon.com'),
  ('microsoft', 'Microsoft', 'https://azure.microsoft.com'),
  ('github', 'GitHub', 'https://github.com'),
  ('openrouter', 'OpenRouter', 'https://openrouter.ai'),
  ('databricks', 'Databricks', 'https://www.databricks.com'),
  ('fixture-relay', '构造的中转站', NULL);

INSERT INTO region VALUES
  ('us', 'geo', '美国地理区'),
  ('in-region', 'in_region', '仅区域内部署');

INSERT INTO channel VALUES
  ('aws-bedrock', 'aws', 'cloud_partner', 'Amazon Bedrock',
   'https://aws.amazon.com/bedrock/pricing/'),
  ('azure-foundry', 'microsoft', 'cloud_partner', 'Microsoft Foundry', NULL),
  ('kiro', 'aws', 'tool_bundle', 'Kiro', 'https://kiro.dev/pricing/'),
  ('openrouter', 'openrouter', 'aggregator', 'OpenRouter', 'https://openrouter.ai/models'),
  ('github-copilot', 'github', 'tool_bundle', 'GitHub Copilot', NULL),
  ('databricks', 'databricks', 'enterprise_platform', 'Databricks Model Serving',
   'https://www.databricks.com/product/pricing/proprietary-foundation-model-serving'),
  ('fixture-relay', 'fixture-relay', 'relay', '构造的中转站', NULL);

INSERT INTO billing_unit VALUES
  ('kiro-credit', 'tool_credit', 'aws', 'Kiro credit'),
  ('copilot-premium-request', 'request', 'github', 'Copilot 旧制 premium request'),
  ('openrouter-credit', 'platform_credit', 'openrouter', 'OpenRouter 余额（美元额度）'),
  ('databricks-dbu', 'platform_credit', 'databricks', 'Databricks Unit'),
  ('fixture-relay-quota', 'quota', 'fixture-relay', '中转站内部额度（500000 = 1 站内美元）'),
  ('fixture-relay-usd', 'quota', 'fixture-relay', '中转站站内"美元"');

INSERT INTO meter VALUES
  ('request', 'request', 1, '一次请求'),
  ('relative_usage', 'relative', 1, '相对渠道基准用量的倍率');

INSERT INTO source (source_id, url, publisher_org_id, kind, machine_readable,
  retrieved_at)
VALUES
  ('foundry-claude@2026-09-24',
   'https://platform.claude.com/docs/en/build-with-claude/claude-in-microsoft-foundry',
   'anthropic', 'official_model_page', 0, '2026-09-24T21:00:00Z'),
  ('kiro-models@2026-09-24', 'https://kiro.dev/docs/models/', 'aws',
   'official_model_page', 0, '2026-09-24T21:00:00Z'),
  ('kiro-changelog@2026-09-24', 'https://kiro.dev/changelog/models/', 'aws',
   'official_announcement', 0, '2026-09-24T21:00:00Z'),
  ('kiro-pricing@2026-09-24', 'https://kiro.dev/pricing/', 'aws',
   'official_pricing_page', 0, '2026-09-24T21:00:00Z'),
  ('openrouter-endpoints@2026-09-24',
   'https://openrouter.ai/api/v1/models/anthropic/claude-sonnet-4.6/endpoints',
   'openrouter', 'official_api', 1, '2026-09-24T21:00:00Z'),
  ('openrouter-faq@2026-09-24', 'https://openrouter.ai/docs/faq', 'openrouter',
   'official_pricing_page', 0, '2026-09-24T21:00:00Z'),
  ('copilot-models-pricing@2026-09-24',
   'https://github.com/github/docs/tree/main/data/tables/copilot', 'github',
   'official_repository', 1, '2026-09-24T21:00:00Z'),
  ('copilot-requests@2026-09-24',
   'https://docs.github.com/en/copilot/concepts/billing/copilot-requests', 'github',
   'official_pricing_page', 0, '2026-09-24T21:00:00Z'),
  ('bedrock-gpt55-card@2026-09-24',
   'https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-openai-gpt-55.html',
   'aws', 'official_model_page', 0, '2026-09-24T21:00:00Z'),
  ('bedrock-openai-blog@2026-09-24',
   'https://aws.amazon.com/blogs/machine-learning/openai-models-and-codex-on-amazon-bedrock-are-now-generally-available/',
   'aws', 'official_announcement', 0, '2026-09-24T21:00:00Z'),
  ('databricks-pricing@2026-09-24',
   'https://www.databricks.com/product/pricing/proprietary-foundation-model-serving',
   'databricks', 'official_pricing_page', 0, '2026-09-24T21:00:00Z');

INSERT INTO model (model_id, vendor_org_id, kind, family, display_name) VALUES
  ('claude-sonnet-4-6', 'anthropic', 'vendor_model', 'claude-sonnet',
   'Claude Sonnet 4.6'),
  ('claude-opus-4-7', 'anthropic', 'vendor_model', 'claude-opus', 'Claude Opus 4.7'),
  ('gpt-5.6-luna', 'openai', 'vendor_model', 'gpt-5.6', 'GPT-5.6 Luna'),
  ('gpt-5.5', 'openai', 'vendor_model', 'gpt-5', 'GPT-5.5'),
  ('kiro-auto', 'aws', 'router', NULL, 'Kiro Auto');

INSERT INTO offering (offering_id, channel_id, model_id, variant) VALUES
  ('azure-foundry/claude-opus-4-7@hosted-on-anthropic', 'azure-foundry',
   'claude-opus-4-7', 'hosted-on-anthropic'),
  ('kiro/claude-sonnet-5', 'kiro', 'claude-sonnet-5', ''),
  ('kiro/kiro-auto', 'kiro', 'kiro-auto', ''),
  ('aws-bedrock/claude-sonnet-5', 'aws-bedrock', 'claude-sonnet-5', ''),
  ('kiro/gpt-5.6-luna', 'kiro', 'gpt-5.6-luna', ''),
  ('openrouter/claude-sonnet-4-6', 'openrouter', 'claude-sonnet-4-6', ''),
  ('anthropic-api/claude-sonnet-4-6', 'anthropic-api', 'claude-sonnet-4-6', ''),
  ('aws-bedrock/claude-sonnet-4-6', 'aws-bedrock', 'claude-sonnet-4-6', ''),
  ('fixture-relay/claude-opus-5-5', 'fixture-relay', 'claude-opus-5-5', ''),
  ('github-copilot/claude-opus-4-7', 'github-copilot', 'claude-opus-4-7', ''),
  ('aws-bedrock/gpt-5.5', 'aws-bedrock', 'gpt-5.5', ''),
  ('databricks/claude-opus-5-5', 'databricks', 'claude-opus-5-5', '');

INSERT INTO plan VALUES
  ('kiro-pro', 'kiro', 'Kiro Pro'),
  ('fixture-relay/default-group', 'fixture-relay', '默认分组'),
  ('copilot-pro', 'github-copilot', 'Copilot Pro（按 token 新制）'),
  ('copilot-pro-annual-legacy', 'github-copilot', 'Copilot Pro 年付旧制');

INSERT INTO offering_revision (offering_id, channel_model_id, availability,
  operator_org_id, seller_org_id, billing_org_id, vendor_relationship, notes,
  valid_from, date_basis, recorded_at, source_id)
VALUES ('azure-foundry/claude-opus-4-7@hosted-on-anthropic', 'claude-opus-4-7',
  'available', 'anthropic', 'anthropic', 'microsoft', 'contracted_partner',
  '请求里的 model 填用户自定义的 deployment name', '2026-09-01T00:00:00Z',
  'first_observed', '2026-09-24T21:00:00Z', 'foundry-claude@2026-09-24');

INSERT INTO offering_revision (offering_id, channel_model_id, availability,
  operator_org_id, seller_org_id, billing_org_id, vendor_relationship,
  discloses_upstream, valid_from, date_basis, recorded_at, source_id)
VALUES ('kiro/claude-sonnet-5', 'claude-sonnet-5', 'available', 'aws', 'aws', 'aws',
  'disclosed_reseller', 1, '2026-09-01T00:00:00Z', 'first_observed',
  '2026-09-24T21:00:00Z', 'kiro-models@2026-09-24');
INSERT INTO offering_route (offering_id, upstream_offering_id, routing, valid_from,
  date_basis, recorded_at, source_id)
VALUES ('kiro/claude-sonnet-5', 'aws-bedrock/claude-sonnet-5', 'sole',
  '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
  'kiro-models@2026-09-24');

INSERT INTO price_series (price_series_id, channel_id, offering_id, region_id,
  price_unit_id, plan_id, upstream_offering_id)
VALUES
  ('kiro/claude-sonnet-5/standard/global/kiro-credit', 'kiro', 'kiro/claude-sonnet-5',
   'global', 'kiro-credit', NULL, NULL),
  ('kiro/gpt-5.6-luna/standard/global/kiro-credit', 'kiro', 'kiro/gpt-5.6-luna',
   'global', 'kiro-credit', NULL, NULL),
  ('openrouter/claude-sonnet-4-6/standard/global/USD', 'openrouter',
   'openrouter/claude-sonnet-4-6', 'global', 'USD', NULL, NULL),
  ('openrouter/claude-sonnet-4-6/standard/global/USD'
     || '/via:anthropic-api/claude-sonnet-4-6', 'openrouter',
   'openrouter/claude-sonnet-4-6', 'global', 'USD', NULL,
   'anthropic-api/claude-sonnet-4-6'),
  ('openrouter/claude-sonnet-4-6/standard/us/USD/via:aws-bedrock/claude-sonnet-4-6',
   'openrouter', 'openrouter/claude-sonnet-4-6', 'us', 'USD', NULL,
   'aws-bedrock/claude-sonnet-4-6'),
  ('fixture-relay/claude-opus-5-5/standard/global/fixture-relay-usd'
     || '/plan:fixture-relay/default-group', 'fixture-relay',
   'fixture-relay/claude-opus-5-5', 'global', 'fixture-relay-usd',
   'fixture-relay/default-group', NULL),
  ('github-copilot/claude-opus-4-7/standard/global/USD', 'github-copilot',
   'github-copilot/claude-opus-4-7', 'global', 'USD', NULL, NULL),
  ('github-copilot/claude-opus-4-7/standard/global/copilot-premium-request'
     || '/plan:copilot-pro-annual-legacy', 'github-copilot',
   'github-copilot/claude-opus-4-7', 'global', 'copilot-premium-request',
   'copilot-pro-annual-legacy', NULL),
  ('aws-bedrock/gpt-5.5/standard/in-region/USD', 'aws-bedrock', 'aws-bedrock/gpt-5.5',
   'in-region', 'USD', NULL, NULL),
  ('databricks/claude-opus-5-5/standard/global/databricks-dbu', 'databricks',
   'databricks/claude-opus-5-5', 'global', 'databricks-dbu', NULL, NULL);

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES (201, 'kiro/claude-sonnet-5/standard/global/kiro-credit',
  '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
  'kiro-models@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (201, 'relative_usage', '1.3');

INSERT INTO price_card (price_card_id, price_series_id, context_tier_bound,
  valid_from, valid_to, date_basis, recorded_at, source_id)
VALUES
  (202, 'kiro/gpt-5.6-luna/standard/global/kiro-credit', NULL,
   '2026-07-14T00:00:00Z', '2026-07-31T00:00:00Z', 'official_effective',
   '2026-09-24T21:00:00Z', 'kiro-changelog@2026-09-24'),
  (203, 'kiro/gpt-5.6-luna/standard/global/kiro-credit', NULL,
   '2026-07-31T00:00:00Z', '2026-09-14T00:00:00Z', 'official_effective',
   '2026-09-24T21:00:00Z', 'kiro-changelog@2026-09-24'),
  (204, 'kiro/gpt-5.6-luna/standard/global/kiro-credit', 'gt',
   '2026-09-14T00:00:00Z', NULL, 'official_effective',
   '2026-09-24T21:00:00Z', 'kiro-changelog@2026-09-24');
INSERT INTO price_rate VALUES
  (202, 'relative_usage', 0, '0.6'),
  (203, 'relative_usage', 0, '0.1'),
  (204, 'relative_usage', 0, '1.1'),
  (204, 'relative_usage', 272000, '2.2');

INSERT INTO plan_revision (plan_revision_id, plan_id, price_amount, price_unit_id,
  billing_period, valid_from, date_basis, recorded_at, source_id)
VALUES (201, 'kiro-pro', '20', 'USD', 'month', '2026-09-01T00:00:00Z',
  'first_observed', '2026-09-24T21:00:00Z', 'kiro-pricing@2026-09-24');
INSERT INTO plan_allowance (plan_revision_id, unit_id, refresh_window, quantity)
VALUES (201, 'kiro-credit', 'month', '1000');

INSERT INTO unit_rate_series (unit_rate_series_id, unit_id, value_unit_id, rate_kind,
  channel_id, plan_id, min_purchase)
VALUES
  ('kiro-credit>USD/overage/global/channel:kiro', 'kiro-credit', 'USD', 'overage',
   'kiro', NULL, NULL),
  ('kiro-credit>USD/included/global/channel:kiro/plan:kiro-pro', 'kiro-credit', 'USD',
   'included', 'kiro', 'kiro-pro', NULL),
  ('openrouter-credit>USD/top_up/global/channel:openrouter', 'openrouter-credit',
   'USD', 'top_up', 'openrouter', NULL, NULL),
  ('fixture-relay-quota>fixture-relay-usd/list/global/channel:fixture-relay',
   'fixture-relay-quota', 'fixture-relay-usd', 'list', 'fixture-relay', NULL, NULL),
  ('fixture-relay-usd>CNY/top_up/global/channel:fixture-relay', 'fixture-relay-usd',
   'CNY', 'top_up', 'fixture-relay', NULL, NULL),
  ('fixture-relay-usd>CNY/top_up/global/channel:fixture-relay/min:100',
   'fixture-relay-usd', 'CNY', 'top_up', 'fixture-relay', NULL, '100'),
  ('copilot-premium-request>USD/overage/global/channel:github-copilot',
   'copilot-premium-request', 'USD', 'overage', 'github-copilot', NULL, NULL);

INSERT INTO unit_rate (unit_rate_series_id, value_amount, derivation, valid_from,
  date_basis, recorded_at, source_id)
VALUES
  ('kiro-credit>USD/overage/global/channel:kiro', '0.04', 'published',
   '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
   'kiro-pricing@2026-09-24'),
  ('kiro-credit>USD/included/global/channel:kiro/plan:kiro-pro', '0.02',
   'derived_from_plan', '2026-09-01T00:00:00Z', 'first_observed',
   '2026-09-24T21:00:00Z', 'kiro-pricing@2026-09-24');

INSERT INTO offering_revision (offering_id, channel_model_id, availability,
  seller_org_id, billing_org_id, vendor_relationship, discloses_upstream, valid_from,
  date_basis, recorded_at, source_id)
VALUES ('openrouter/claude-sonnet-4-6', 'anthropic/claude-sonnet-4.6', 'available',
  'openrouter', 'openrouter', 'disclosed_reseller', 1, '2026-09-01T00:00:00Z',
  'first_observed', '2026-09-24T21:00:00Z', 'openrouter-endpoints@2026-09-24');
INSERT INTO offering_route (offering_id, upstream_offering_id, routing, valid_from,
  date_basis, recorded_at, source_id)
VALUES
  ('openrouter/claude-sonnet-4-6', 'anthropic-api/claude-sonnet-4-6', 'load_balanced',
   '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
   'openrouter-endpoints@2026-09-24'),
  ('openrouter/claude-sonnet-4-6', 'aws-bedrock/claude-sonnet-4-6', 'load_balanced',
   '2026-09-01T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
   'openrouter-endpoints@2026-09-24');
INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES
  (205, 'openrouter/claude-sonnet-4-6/standard/global/USD', '2026-09-01T00:00:00Z',
   'first_observed', '2026-09-24T21:00:00Z', 'openrouter-endpoints@2026-09-24'),
  (206, 'openrouter/claude-sonnet-4-6/standard/global/USD'
          || '/via:anthropic-api/claude-sonnet-4-6', '2026-09-01T00:00:00Z',
   'first_observed', '2026-09-24T21:00:00Z', 'openrouter-endpoints@2026-09-24'),
  (207, 'openrouter/claude-sonnet-4-6/standard/us/USD'
          || '/via:aws-bedrock/claude-sonnet-4-6', '2026-09-01T00:00:00Z',
   'first_observed', '2026-09-24T21:00:00Z', 'openrouter-endpoints@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (205, 'input', '3'), (205, 'output', '15'),
  (206, 'input', '3'), (206, 'output', '15'),
  (207, 'input', '3.3'), (207, 'output', '16.5');
INSERT INTO unit_rate (unit_rate_series_id, value_amount, notes, valid_from,
  date_basis, recorded_at, source_id)
VALUES ('openrouter-credit>USD/top_up/global/channel:openrouter', '1.055',
  '银行卡充值收 5.5%，最低 0.80 USD', '2026-09-01T00:00:00Z', 'first_observed',
  '2026-09-24T21:00:00Z', 'openrouter-faq@2026-09-24');
INSERT INTO pricing_rule (rule_key, channel_id, kind) VALUES
  ('openrouter/byok-fee', 'openrouter', 'byok_fee');
INSERT INTO pricing_rule_revision (pricing_rule_revision_id, rule_key, factor,
  free_allowance, notes, valid_from, date_basis, recorded_at, source_id)
VALUES (201, 'openrouter/byok-fee', '0.05', '25000',
  '每月前 25,000 USD 的 BYOK 用量免收', '2026-09-01T00:00:00Z', 'first_observed',
  '2026-09-24T21:00:00Z', 'openrouter-faq@2026-09-24');

INSERT INTO offering_revision (offering_id, channel_model_id, availability,
  seller_org_id, vendor_relationship, discloses_upstream, valid_from, date_basis,
  recorded_at, source_id)
VALUES ('fixture-relay/claude-opus-5-5', 'claude-opus-5-5', 'available',
  'fixture-relay', 'self_declared_official', 0, '2026-09-01T00:00:00Z', 'inferred',
  '2026-09-24T21:00:00Z', 'fixture-constructed');
INSERT INTO pricing_rule (rule_key, channel_id, plan_id, kind, reference_channel_id)
VALUES ('fixture-relay/default-group-markup', 'fixture-relay',
  'fixture-relay/default-group', 'markup', 'anthropic-api');
INSERT INTO pricing_rule_revision (pricing_rule_revision_id, rule_key, factor,
  valid_from, date_basis, recorded_at, source_id)
VALUES (202, 'fixture-relay/default-group-markup', '1.5', '2026-09-01T00:00:00Z',
  'inferred', '2026-09-24T21:00:00Z', 'fixture-constructed');
INSERT INTO price_card (price_card_id, price_series_id, derivation,
  derived_from_rule_revision_id, derived_from_card_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES (208, 'fixture-relay/claude-opus-5-5/standard/global/fixture-relay-usd'
               || '/plan:fixture-relay/default-group',
  'computed_from_rule', 202, 101, '2026-09-21T00:00:00Z', 'inferred',
  '2026-09-24T21:00:00Z', 'fixture-constructed');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (208, 'input', '6'), (208, 'output', '30');
INSERT INTO unit_rate (unit_rate_series_id, value_amount, valid_from, date_basis,
  recorded_at, source_id)
VALUES
  ('fixture-relay-quota>fixture-relay-usd/list/global/channel:fixture-relay',
   '0.000002', '2026-09-01T00:00:00Z', 'inferred', '2026-09-24T21:00:00Z',
   'fixture-constructed'),
  ('fixture-relay-usd>CNY/top_up/global/channel:fixture-relay', '7.3',
   '2026-09-01T00:00:00Z', 'inferred', '2026-09-24T21:00:00Z', 'fixture-constructed'),
  ('fixture-relay-usd>CNY/top_up/global/channel:fixture-relay/min:100', '6.935',
   '2026-09-01T00:00:00Z', 'inferred', '2026-09-24T21:00:00Z', 'fixture-constructed');

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES
  (209, 'github-copilot/claude-opus-4-7/standard/global/USD', '2026-06-01T00:00:00Z',
   'official_effective', '2026-09-24T21:00:00Z', 'copilot-models-pricing@2026-09-24'),
  (210, 'github-copilot/claude-opus-4-7/standard/global/copilot-premium-request'
          || '/plan:copilot-pro-annual-legacy', '2026-06-01T00:00:00Z',
   'official_effective', '2026-09-24T21:00:00Z', 'copilot-requests@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (209, 'input', '5'), (209, 'cache_read', '0.50'), (209, 'output', '25'),
  (210, 'request', '27');
INSERT INTO unit_rate (unit_rate_series_id, value_amount, valid_from, date_basis,
  recorded_at, source_id)
VALUES ('copilot-premium-request>USD/overage/global/channel:github-copilot', '0.04',
  '2026-06-01T00:00:00Z', 'official_effective', '2026-09-24T21:00:00Z',
  'copilot-requests@2026-09-24');

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id, notes)
VALUES (211, 'aws-bedrock/gpt-5.5/standard/in-region/USD', '2026-06-01T00:00:00Z',
  'official_effective', '2026-09-24T21:00:00Z', 'bedrock-gpt55-card@2026-09-24',
  '仅 In-Region 部署；价格含比 OpenAI 标价高 10% 的费用');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (211, 'input', '5.50'), (211, 'output', '33');
INSERT INTO price_evidence (price_card_id, source_id, stance, notes) VALUES
  (211, 'bedrock-openai-blog@2026-09-24', 'contradicts', '博客称与 OpenAI 同价');

INSERT INTO price_card (price_card_id, price_series_id, valid_from, date_basis,
  recorded_at, source_id)
VALUES (212, 'databricks/claude-opus-5-5/standard/global/databricks-dbu',
  '2026-09-21T00:00:00Z', 'first_observed', '2026-09-24T21:00:00Z',
  'databricks-pricing@2026-09-24');
INSERT INTO price_rate (price_card_id, meter_id, amount) VALUES
  (212, 'input', '57.143'), (212, 'output', '285.714');
