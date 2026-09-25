-- 只增不改：由 scripts/gen_append_only.py 从 DDL 与 schema/tables.toml 生成，请勿手工编辑。
-- SCD2 版本表只允许补写一次 superseded_at 与 supersede_reason；
-- 身份表只允许改写 schema/tables.toml 中声明为 Type 1 的描述列；任何表都不允许删除。

-- organization
CREATE TRIGGER organization_no_update BEFORE UPDATE ON organization
  WHEN OLD.org_id IS NOT NEW.org_id
BEGIN SELECT RAISE(ABORT, 'organization：只允许改写 Type 1 列（display_name、homepage_url）'); END;
CREATE TRIGGER organization_no_delete BEFORE DELETE ON organization
BEGIN SELECT RAISE(ABORT, 'organization：不允许删除，请以新版本或更正代替'); END;

-- region
CREATE TRIGGER region_no_update BEFORE UPDATE ON region
  WHEN OLD.region_id IS NOT NEW.region_id
     OR OLD.kind IS NOT NEW.kind
BEGIN SELECT RAISE(ABORT, 'region：只允许改写 Type 1 列（description）'); END;
CREATE TRIGGER region_no_delete BEFORE DELETE ON region
BEGIN SELECT RAISE(ABORT, 'region：不允许删除，请以新版本或更正代替'); END;

-- channel
CREATE TRIGGER channel_no_update BEFORE UPDATE ON channel
  WHEN OLD.channel_id IS NOT NEW.channel_id
     OR OLD.owner_org_id IS NOT NEW.owner_org_id
     OR OLD.kind IS NOT NEW.kind
BEGIN SELECT RAISE(ABORT, 'channel：只允许改写 Type 1 列（display_name、pricing_url）'); END;
CREATE TRIGGER channel_no_delete BEFORE DELETE ON channel
BEGIN SELECT RAISE(ABORT, 'channel：不允许删除，请以新版本或更正代替'); END;

-- client
CREATE TRIGGER client_no_update BEFORE UPDATE ON client
  WHEN OLD.client_id IS NOT NEW.client_id
BEGIN SELECT RAISE(ABORT, 'client：只允许改写 Type 1 列（display_name、notes）'); END;
CREATE TRIGGER client_no_delete BEFORE DELETE ON client
BEGIN SELECT RAISE(ABORT, 'client：不允许删除，请以新版本或更正代替'); END;

-- label_namespace
CREATE TRIGGER label_namespace_no_update BEFORE UPDATE ON label_namespace
  WHEN OLD.namespace_id IS NOT NEW.namespace_id
     OR OLD.kind IS NOT NEW.kind
     OR OLD.channel_id IS NOT NEW.channel_id
     OR OLD.client_id IS NOT NEW.client_id
BEGIN SELECT RAISE(ABORT, 'label_namespace：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER label_namespace_no_delete BEFORE DELETE ON label_namespace
BEGIN SELECT RAISE(ABORT, 'label_namespace：不允许删除，请以新版本或更正代替'); END;

-- billing_unit
CREATE TRIGGER billing_unit_no_update BEFORE UPDATE ON billing_unit
  WHEN OLD.unit_id IS NOT NEW.unit_id
     OR OLD.kind IS NOT NEW.kind
     OR OLD.issuer_org_id IS NOT NEW.issuer_org_id
BEGIN SELECT RAISE(ABORT, 'billing_unit：只允许改写 Type 1 列（description）'); END;
CREATE TRIGGER billing_unit_no_delete BEFORE DELETE ON billing_unit
BEGIN SELECT RAISE(ABORT, 'billing_unit：不允许删除，请以新版本或更正代替'); END;

-- meter
CREATE TRIGGER meter_no_update BEFORE UPDATE ON meter
  WHEN OLD.meter_id IS NOT NEW.meter_id
     OR OLD.quantity_unit IS NOT NEW.quantity_unit
     OR OLD.per_quantity IS NOT NEW.per_quantity
BEGIN SELECT RAISE(ABORT, 'meter：只允许改写 Type 1 列（description）'); END;
CREATE TRIGGER meter_no_delete BEFORE DELETE ON meter
BEGIN SELECT RAISE(ABORT, 'meter：不允许删除，请以新版本或更正代替'); END;

-- source
CREATE TRIGGER source_no_update BEFORE UPDATE ON source
  WHEN OLD.source_id IS NOT NEW.source_id
     OR OLD.url IS NOT NEW.url
     OR OLD.publisher_org_id IS NOT NEW.publisher_org_id
     OR OLD.kind IS NOT NEW.kind
     OR OLD.machine_readable IS NOT NEW.machine_readable
     OR OLD.retrieved_at IS NOT NEW.retrieved_at
     OR OLD.page_updated_on IS NOT NEW.page_updated_on
     OR OLD.content_sha256 IS NOT NEW.content_sha256
     OR OLD.snapshot_path IS NOT NEW.snapshot_path
     OR OLD.notes IS NOT NEW.notes
BEGIN SELECT RAISE(ABORT, 'source：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER source_no_delete BEFORE DELETE ON source
BEGIN SELECT RAISE(ABORT, 'source：不允许删除，请以新版本或更正代替'); END;

-- time_window
CREATE TRIGGER time_window_no_update BEFORE UPDATE ON time_window
  WHEN OLD.window_id IS NOT NEW.window_id
     OR OLD.time_zone IS NOT NEW.time_zone
     OR OLD.iso_weekdays IS NOT NEW.iso_weekdays
     OR OLD.ranges IS NOT NEW.ranges
     OR OLD.holiday_calendar IS NOT NEW.holiday_calendar
BEGIN SELECT RAISE(ABORT, 'time_window：只允许改写 Type 1 列（description）'); END;
CREATE TRIGGER time_window_no_delete BEFORE DELETE ON time_window
BEGIN SELECT RAISE(ABORT, 'time_window：不允许删除，请以新版本或更正代替'); END;

-- model
CREATE TRIGGER model_no_update BEFORE UPDATE ON model
  WHEN OLD.model_id IS NOT NEW.model_id
     OR OLD.vendor_org_id IS NOT NEW.vendor_org_id
     OR OLD.kind IS NOT NEW.kind
BEGIN SELECT RAISE(ABORT, 'model：只允许改写 Type 1 列（family、display_name）'); END;
CREATE TRIGGER model_no_delete BEFORE DELETE ON model
BEGIN SELECT RAISE(ABORT, 'model：不允许删除，请以新版本或更正代替'); END;

-- model_revision
CREATE TRIGGER model_revision_no_update BEFORE UPDATE ON model_revision
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.model_revision_id IS NOT NEW.model_revision_id
     OR OLD.model_id IS NOT NEW.model_id
     OR OLD.lifecycle IS NOT NEW.lifecycle
     OR OLD.released_on IS NOT NEW.released_on
     OR OLD.deprecated_on IS NOT NEW.deprecated_on
     OR OLD.retires_on IS NOT NEW.retires_on
     OR OLD.context_window IS NOT NEW.context_window
     OR OLD.max_input_tokens IS NOT NEW.max_input_tokens
     OR OLD.max_output_tokens IS NOT NEW.max_output_tokens
     OR OLD.knowledge_cutoff IS NOT NEW.knowledge_cutoff
     OR OLD.training_cutoff IS NOT NEW.training_cutoff
     OR OLD.reasoning IS NOT NEW.reasoning
     OR OLD.tokenizer IS NOT NEW.tokenizer
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'model_revision：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER model_revision_no_delete BEFORE DELETE ON model_revision
BEGIN SELECT RAISE(ABORT, 'model_revision：不允许删除，请以新版本或更正代替'); END;

-- model_revision_modality
CREATE TRIGGER model_revision_modality_no_update BEFORE UPDATE ON model_revision_modality
  WHEN OLD.model_revision_id IS NOT NEW.model_revision_id
     OR OLD.direction IS NOT NEW.direction
     OR OLD.modality IS NOT NEW.modality
BEGIN SELECT RAISE(ABORT, 'model_revision_modality：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER model_revision_modality_no_delete BEFORE DELETE ON model_revision_modality
BEGIN SELECT RAISE(ABORT, 'model_revision_modality：不允许删除，请以新版本或更正代替'); END;

-- model_revision_effort
CREATE TRIGGER model_revision_effort_no_update BEFORE UPDATE ON model_revision_effort
  WHEN OLD.model_revision_id IS NOT NEW.model_revision_id
     OR OLD.effort IS NOT NEW.effort
     OR OLD.is_default IS NOT NEW.is_default
BEGIN SELECT RAISE(ABORT, 'model_revision_effort：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER model_revision_effort_no_delete BEFORE DELETE ON model_revision_effort
BEGIN SELECT RAISE(ABORT, 'model_revision_effort：不允许删除，请以新版本或更正代替'); END;

-- client_revision
CREATE TRIGGER client_revision_no_update BEFORE UPDATE ON client_revision
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.client_revision_id IS NOT NEW.client_revision_id
     OR OLD.client_id IS NOT NEW.client_id
     OR OLD.reference_channel_id IS NOT NEW.reference_channel_id
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'client_revision：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER client_revision_no_delete BEFORE DELETE ON client_revision
BEGIN SELECT RAISE(ABORT, 'client_revision：不允许删除，请以新版本或更正代替'); END;

-- offering
CREATE TRIGGER offering_no_update BEFORE UPDATE ON offering
  WHEN OLD.offering_id IS NOT NEW.offering_id
     OR OLD.channel_id IS NOT NEW.channel_id
     OR OLD.model_id IS NOT NEW.model_id
     OR OLD.variant IS NOT NEW.variant
BEGIN SELECT RAISE(ABORT, 'offering：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER offering_no_delete BEFORE DELETE ON offering
BEGIN SELECT RAISE(ABORT, 'offering：不允许删除，请以新版本或更正代替'); END;

-- model_identifier
CREATE TRIGGER model_identifier_no_update BEFORE UPDATE ON model_identifier
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.model_identifier_id IS NOT NEW.model_identifier_id
     OR OLD.namespace_id IS NOT NEW.namespace_id
     OR OLD.kind IS NOT NEW.kind
     OR OLD.identifier IS NOT NEW.identifier
     OR OLD.model_id IS NOT NEW.model_id
     OR OLD.offering_id IS NOT NEW.offering_id
     OR OLD.implied_effort IS NOT NEW.implied_effort
     OR OLD.implied_variant IS NOT NEW.implied_variant
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'model_identifier：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER model_identifier_no_delete BEFORE DELETE ON model_identifier
BEGIN SELECT RAISE(ABORT, 'model_identifier：不允许删除，请以新版本或更正代替'); END;

-- offering_revision
CREATE TRIGGER offering_revision_no_update BEFORE UPDATE ON offering_revision
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.offering_revision_id IS NOT NEW.offering_revision_id
     OR OLD.offering_id IS NOT NEW.offering_id
     OR OLD.api_surface IS NOT NEW.api_surface
     OR OLD.availability IS NOT NEW.availability
     OR OLD.operator_org_id IS NOT NEW.operator_org_id
     OR OLD.seller_org_id IS NOT NEW.seller_org_id
     OR OLD.billing_org_id IS NOT NEW.billing_org_id
     OR OLD.vendor_relationship IS NOT NEW.vendor_relationship
     OR OLD.discloses_upstream IS NOT NEW.discloses_upstream
     OR OLD.context_window IS NOT NEW.context_window
     OR OLD.max_output_tokens IS NOT NEW.max_output_tokens
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'offering_revision：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER offering_revision_no_delete BEFORE DELETE ON offering_revision
BEGIN SELECT RAISE(ABORT, 'offering_revision：不允许删除，请以新版本或更正代替'); END;

-- offering_route
CREATE TRIGGER offering_route_no_update BEFORE UPDATE ON offering_route
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.offering_route_id IS NOT NEW.offering_route_id
     OR OLD.offering_id IS NOT NEW.offering_id
     OR OLD.upstream_offering_id IS NOT NEW.upstream_offering_id
     OR OLD.routing IS NOT NEW.routing
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'offering_route：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER offering_route_no_delete BEFORE DELETE ON offering_route
BEGIN SELECT RAISE(ABORT, 'offering_route：不允许删除，请以新版本或更正代替'); END;

-- plan
CREATE TRIGGER plan_no_update BEFORE UPDATE ON plan
  WHEN OLD.plan_id IS NOT NEW.plan_id
     OR OLD.channel_id IS NOT NEW.channel_id
BEGIN SELECT RAISE(ABORT, 'plan：只允许改写 Type 1 列（display_name）'); END;
CREATE TRIGGER plan_no_delete BEFORE DELETE ON plan
BEGIN SELECT RAISE(ABORT, 'plan：不允许删除，请以新版本或更正代替'); END;

-- plan_revision
CREATE TRIGGER plan_revision_no_update BEFORE UPDATE ON plan_revision
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.plan_revision_id IS NOT NEW.plan_revision_id
     OR OLD.plan_id IS NOT NEW.plan_id
     OR OLD.price_amount IS NOT NEW.price_amount
     OR OLD.price_unit_id IS NOT NEW.price_unit_id
     OR OLD.billing_period IS NOT NEW.billing_period
     OR OLD.usage_limit_text IS NOT NEW.usage_limit_text
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'plan_revision：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER plan_revision_no_delete BEFORE DELETE ON plan_revision
BEGIN SELECT RAISE(ABORT, 'plan_revision：不允许删除，请以新版本或更正代替'); END;

-- plan_revision_client
CREATE TRIGGER plan_revision_client_no_update BEFORE UPDATE ON plan_revision_client
  WHEN OLD.plan_revision_id IS NOT NEW.plan_revision_id
     OR OLD.client_id IS NOT NEW.client_id
BEGIN SELECT RAISE(ABORT, 'plan_revision_client：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER plan_revision_client_no_delete BEFORE DELETE ON plan_revision_client
BEGIN SELECT RAISE(ABORT, 'plan_revision_client：不允许删除，请以新版本或更正代替'); END;

-- plan_allowance
CREATE TRIGGER plan_allowance_no_update BEFORE UPDATE ON plan_allowance
  WHEN OLD.plan_revision_id IS NOT NEW.plan_revision_id
     OR OLD.pool IS NOT NEW.pool
     OR OLD.unit_id IS NOT NEW.unit_id
     OR OLD.refresh_window IS NOT NEW.refresh_window
     OR OLD.quantity IS NOT NEW.quantity
     OR OLD.expires_after IS NOT NEW.expires_after
     OR OLD.notes IS NOT NEW.notes
BEGIN SELECT RAISE(ABORT, 'plan_allowance：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER plan_allowance_no_delete BEFORE DELETE ON plan_allowance
BEGIN SELECT RAISE(ABORT, 'plan_allowance：不允许删除，请以新版本或更正代替'); END;

-- unit_rate_series
CREATE TRIGGER unit_rate_series_no_update BEFORE UPDATE ON unit_rate_series
  WHEN OLD.unit_rate_series_id IS NOT NEW.unit_rate_series_id
     OR OLD.unit_id IS NOT NEW.unit_id
     OR OLD.value_unit_id IS NOT NEW.value_unit_id
     OR OLD.rate_kind IS NOT NEW.rate_kind
     OR OLD.region_id IS NOT NEW.region_id
     OR OLD.channel_id IS NOT NEW.channel_id
     OR OLD.plan_id IS NOT NEW.plan_id
     OR OLD.min_purchase IS NOT NEW.min_purchase
BEGIN SELECT RAISE(ABORT, 'unit_rate_series：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER unit_rate_series_no_delete BEFORE DELETE ON unit_rate_series
BEGIN SELECT RAISE(ABORT, 'unit_rate_series：不允许删除，请以新版本或更正代替'); END;

-- unit_rate
CREATE TRIGGER unit_rate_no_update BEFORE UPDATE ON unit_rate
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.unit_rate_id IS NOT NEW.unit_rate_id
     OR OLD.unit_rate_series_id IS NOT NEW.unit_rate_series_id
     OR OLD.value_amount IS NOT NEW.value_amount
     OR OLD.derivation IS NOT NEW.derivation
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'unit_rate：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER unit_rate_no_delete BEFORE DELETE ON unit_rate
BEGIN SELECT RAISE(ABORT, 'unit_rate：不允许删除，请以新版本或更正代替'); END;

-- pricing_rule
CREATE TRIGGER pricing_rule_no_update BEFORE UPDATE ON pricing_rule
  WHEN OLD.rule_key IS NOT NEW.rule_key
     OR OLD.channel_id IS NOT NEW.channel_id
     OR OLD.plan_id IS NOT NEW.plan_id
     OR OLD.kind IS NOT NEW.kind
     OR OLD.reference_channel_id IS NOT NEW.reference_channel_id
BEGIN SELECT RAISE(ABORT, 'pricing_rule：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER pricing_rule_no_delete BEFORE DELETE ON pricing_rule
BEGIN SELECT RAISE(ABORT, 'pricing_rule：不允许删除，请以新版本或更正代替'); END;

-- pricing_rule_revision
CREATE TRIGGER pricing_rule_revision_no_update BEFORE UPDATE ON pricing_rule_revision
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.pricing_rule_revision_id IS NOT NEW.pricing_rule_revision_id
     OR OLD.rule_key IS NOT NEW.rule_key
     OR OLD.factor IS NOT NEW.factor
     OR OLD.addend IS NOT NEW.addend
     OR OLD.addend_unit_id IS NOT NEW.addend_unit_id
     OR OLD.addend_meter_id IS NOT NEW.addend_meter_id
     OR OLD.free_allowance IS NOT NEW.free_allowance
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'pricing_rule_revision：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER pricing_rule_revision_no_delete BEFORE DELETE ON pricing_rule_revision
BEGIN SELECT RAISE(ABORT, 'pricing_rule_revision：不允许删除，请以新版本或更正代替'); END;

-- pricing_rule_scope_model
CREATE TRIGGER pricing_rule_scope_model_no_update BEFORE UPDATE ON pricing_rule_scope_model
  WHEN OLD.pricing_rule_revision_id IS NOT NEW.pricing_rule_revision_id
     OR OLD.model_id IS NOT NEW.model_id
BEGIN SELECT RAISE(ABORT, 'pricing_rule_scope_model：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER pricing_rule_scope_model_no_delete BEFORE DELETE ON pricing_rule_scope_model
BEGIN SELECT RAISE(ABORT, 'pricing_rule_scope_model：不允许删除，请以新版本或更正代替'); END;

-- pricing_rule_scope_meter
CREATE TRIGGER pricing_rule_scope_meter_no_update BEFORE UPDATE ON pricing_rule_scope_meter
  WHEN OLD.pricing_rule_revision_id IS NOT NEW.pricing_rule_revision_id
     OR OLD.meter_id IS NOT NEW.meter_id
BEGIN SELECT RAISE(ABORT, 'pricing_rule_scope_meter：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER pricing_rule_scope_meter_no_delete BEFORE DELETE ON pricing_rule_scope_meter
BEGIN SELECT RAISE(ABORT, 'pricing_rule_scope_meter：不允许删除，请以新版本或更正代替'); END;

-- price_series
CREATE TRIGGER price_series_no_update BEFORE UPDATE ON price_series
  WHEN OLD.price_series_id IS NOT NEW.price_series_id
     OR OLD.channel_id IS NOT NEW.channel_id
     OR OLD.offering_id IS NOT NEW.offering_id
     OR OLD.service_tier IS NOT NEW.service_tier
     OR OLD.region_id IS NOT NEW.region_id
     OR OLD.price_unit_id IS NOT NEW.price_unit_id
     OR OLD.window_id IS NOT NEW.window_id
     OR OLD.plan_id IS NOT NEW.plan_id
     OR OLD.upstream_offering_id IS NOT NEW.upstream_offering_id
     OR OLD.commitment_term IS NOT NEW.commitment_term
BEGIN SELECT RAISE(ABORT, 'price_series：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER price_series_no_delete BEFORE DELETE ON price_series
BEGIN SELECT RAISE(ABORT, 'price_series：不允许删除，请以新版本或更正代替'); END;

-- price_card
CREATE TRIGGER price_card_no_update BEFORE UPDATE ON price_card
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.price_card_id IS NOT NEW.price_card_id
     OR OLD.price_series_id IS NOT NEW.price_series_id
     OR OLD.context_tier_bound IS NOT NEW.context_tier_bound
     OR OLD.is_promotional IS NOT NEW.is_promotional
     OR OLD.derivation IS NOT NEW.derivation
     OR OLD.derived_from_rule_revision_id IS NOT NEW.derived_from_rule_revision_id
     OR OLD.derived_from_card_id IS NOT NEW.derived_from_card_id
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'price_card：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER price_card_no_delete BEFORE DELETE ON price_card
BEGIN SELECT RAISE(ABORT, 'price_card：不允许删除，请以新版本或更正代替'); END;

-- price_rate
CREATE TRIGGER price_rate_no_update BEFORE UPDATE ON price_rate
  WHEN OLD.price_card_id IS NOT NEW.price_card_id
     OR OLD.meter_id IS NOT NEW.meter_id
     OR OLD.context_min_tokens IS NOT NEW.context_min_tokens
     OR OLD.amount IS NOT NEW.amount
BEGIN SELECT RAISE(ABORT, 'price_rate：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER price_rate_no_delete BEFORE DELETE ON price_rate
BEGIN SELECT RAISE(ABORT, 'price_rate：不允许删除，请以新版本或更正代替'); END;

-- price_evidence
CREATE TRIGGER price_evidence_no_update BEFORE UPDATE ON price_evidence
  WHEN OLD.price_card_id IS NOT NEW.price_card_id
     OR OLD.source_id IS NOT NEW.source_id
     OR OLD.stance IS NOT NEW.stance
     OR OLD.excerpt IS NOT NEW.excerpt
     OR OLD.notes IS NOT NEW.notes
BEGIN SELECT RAISE(ABORT, 'price_evidence：只允许改写 Type 1 列（无）'); END;
CREATE TRIGGER price_evidence_no_delete BEFORE DELETE ON price_evidence
BEGIN SELECT RAISE(ABORT, 'price_evidence：不允许删除，请以新版本或更正代替'); END;

-- price_gap
CREATE TRIGGER price_gap_no_update BEFORE UPDATE ON price_gap
  WHEN OLD.superseded_at IS NOT NULL
     OR NEW.superseded_at IS NULL
     OR OLD.price_gap_id IS NOT NEW.price_gap_id
     OR OLD.namespace_id IS NOT NEW.namespace_id
     OR OLD.label IS NOT NEW.label
     OR OLD.reason IS NOT NEW.reason
     OR OLD.notes IS NOT NEW.notes
     OR OLD.valid_from IS NOT NEW.valid_from
     OR OLD.valid_to IS NOT NEW.valid_to
     OR OLD.date_basis IS NOT NEW.date_basis
     OR OLD.recorded_at IS NOT NEW.recorded_at
     OR OLD.source_id IS NOT NEW.source_id
BEGIN SELECT RAISE(ABORT, 'price_gap：版本行只允许补写一次 superseded_at 与 supersede_reason'); END;
CREATE TRIGGER price_gap_no_delete BEFORE DELETE ON price_gap
BEGIN SELECT RAISE(ABORT, 'price_gap：不允许删除，请以新版本或更正代替'); END;
