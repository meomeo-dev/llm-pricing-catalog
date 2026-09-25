import unittest

from catalog_harness import open_catalog, price_at, unit_value_at

NOW = "2026-09-24T12:00:00Z"


class CommercialRoles(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_operator_seller_and_billing_party_can_differ(self) -> None:
        row = self.db.execute(
            "SELECT operator_org_id, seller_org_id, billing_org_id, vendor_relationship"
            "  FROM offering_revision WHERE offering_id = ?",
            ("azure-foundry/claude-opus-4-7@hosted-on-anthropic",)).fetchone()
        self.assertEqual(tuple(row), ("anthropic", "anthropic", "microsoft",
                                      "contracted_partner"))

    def test_hosting_variant_is_part_of_offering_identity(self) -> None:
        bare = price_at(self.db, channel_id="azure-foundry", label="claude-opus-4-7",
                        at=NOW)
        self.assertIsNone(bare["card"])

    def test_tool_offering_names_its_upstream(self) -> None:
        upstreams = self.db.execute(
            "SELECT upstream_offering_id, routing FROM offering_route"
            " WHERE offering_id = 'kiro/claude-sonnet-5'").fetchall()
        self.assertEqual([tuple(r) for r in upstreams],
                         [("aws-bedrock/claude-sonnet-5", "sole")])


class UpstreamSpecificPrices(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()
        self.query = dict(channel_id="openrouter", label="claude-sonnet-4-6", at=NOW)

    def test_listing_price_without_upstream(self) -> None:
        self.assertEqual(price_at(self.db, **self.query)["rates"],
                         {"input": "3", "output": "15"})

    def test_regional_upstream_costs_ten_percent_more(self) -> None:
        via_bedrock = price_at(self.db, **self.query, region_id="us",
                               upstream_offering_id="aws-bedrock/claude-sonnet-4-6")
        self.assertEqual(via_bedrock["rates"], {"input": "3.3", "output": "16.5"})

    def test_top_up_fee_is_a_unit_rate(self) -> None:
        paths = unit_value_at(self.db, unit_id="openrouter-credit",
                              target_unit_id="USD", at=NOW, channel_id="openrouter")
        self.assertEqual(paths, [("top_up", 1.055)])


class CreditsAndMultipliers(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_tool_price_is_a_relative_multiplier_in_credits(self) -> None:
        hit = price_at(self.db, channel_id="kiro", label="claude-sonnet-5", at=NOW,
                       price_unit_id="kiro-credit")
        self.assertEqual(hit["rates"], {"relative_usage": "1.3"})

    def test_multiplier_history_follows_changelog(self) -> None:
        query = dict(channel_id="kiro", label="gpt-5.6-luna",
                     price_unit_id="kiro-credit")
        steps = [("2026-07-20T00:00:00Z", None, "0.6"),
                 ("2026-08-15T00:00:00Z", None, "0.1"),
                 ("2026-09-20T00:00:00Z", 100000, "1.1"),
                 ("2026-09-20T00:00:00Z", 300000, "2.2")]
        for at, tokens, expected in steps:
            with self.subTest(at=at, tokens=tokens):
                hit = price_at(self.db, **query, at=at, input_tokens=tokens)
                self.assertEqual(hit["rates"]["relative_usage"], expected)

    def test_credit_value_depends_on_plan_and_purchase_kind(self) -> None:
        in_plan = unit_value_at(self.db, unit_id="kiro-credit", target_unit_id="USD",
                                at=NOW, channel_id="kiro", plan_id="kiro-pro")
        no_plan = unit_value_at(self.db, unit_id="kiro-credit", target_unit_id="USD",
                                at=NOW, channel_id="kiro")
        self.assertEqual(sorted(in_plan), [("included", 0.02), ("overage", 0.04)])
        self.assertEqual(no_plan, [("overage", 0.04)])

    def test_plan_allowance_is_recorded(self) -> None:
        row = self.db.execute(
            "SELECT a.quantity, a.unit_id, a.refresh_window FROM plan_allowance a"
            "  JOIN plan_revision p USING (plan_revision_id)"
            " WHERE p.plan_id = 'kiro-pro'").fetchone()
        self.assertEqual(tuple(row), ("1000", "kiro-credit", "month"))


class RelayConversionChain(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_relay_price_is_derived_from_rule_and_reference_card(self) -> None:
        hit = price_at(self.db, channel_id="fixture-relay", label="claude-opus-5-5",
                       at=NOW, price_unit_id="fixture-relay-usd",
                       plan_id="fixture-relay/default-group")
        self.assertEqual(hit["rates"], {"input": "6", "output": "30"})
        rule = self.db.execute(
            "SELECT r.kind, v.factor, base.price_series_id FROM price_card c"
            "  JOIN pricing_rule_revision v"
            "    ON v.pricing_rule_revision_id = c.derived_from_rule_revision_id"
            "  JOIN pricing_rule r ON r.rule_key = v.rule_key"
            "  JOIN price_card base ON base.price_card_id = c.derived_from_card_id"
            " WHERE c.price_card_id = ?", (hit["card"],)).fetchone()
        self.assertEqual(tuple(rule), (
            "markup", "1.5", "anthropic-api/claude-opus-5-5/standard/global/USD"))

    def test_quota_converts_to_cny_over_two_hops(self) -> None:
        paths = unit_value_at(self.db, unit_id="fixture-relay-quota",
                              target_unit_id="CNY", at=NOW, channel_id="fixture-relay")
        self.assertEqual([kinds for kinds, _ in paths], ["list > top_up"] * 2)
        self.assertEqual(sorted(round(value, 12) for _, value in paths),
                         [round(0.000002 * 6.935, 12), round(0.000002 * 7.3, 12)])

    def test_channel_scoped_rates_do_not_leak(self) -> None:
        paths = unit_value_at(self.db, unit_id="fixture-relay-usd",
                              target_unit_id="CNY", at=NOW, channel_id="openrouter")
        self.assertEqual(paths, [])


class PlanCohortsAndEvidence(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()
        self.query = dict(channel_id="github-copilot", label="claude-opus-4-7", at=NOW,
                          price_unit_id=None)

    def test_legacy_plan_prices_in_premium_requests(self) -> None:
        hit = price_at(self.db, **self.query, plan_id="copilot-pro-annual-legacy")
        self.assertEqual(hit["rates"], {"request": "27"})
        self.assertEqual(hit["rows"][0]["price_unit_id"], "copilot-premium-request")

    def test_other_plans_fall_back_to_general_token_price(self) -> None:
        for plan in ("copilot-pro", None):
            with self.subTest(plan=plan):
                hit = price_at(self.db, **self.query, plan_id=plan)
                self.assertEqual(hit["rates"]["output"], "25")
                self.assertEqual(hit["rows"][0]["price_unit_id"], "USD")

    def test_contradicting_source_is_kept_beside_the_card(self) -> None:
        hit = price_at(self.db, channel_id="aws-bedrock", label="gpt-5.5", at=NOW,
                       region_id="in-region")
        self.assertEqual(hit["rates"], {"input": "5.50", "output": "33"})
        stances = self.db.execute(
            "SELECT source_id, stance FROM price_evidence WHERE price_card_id = ?",
            (hit["card"],)).fetchall()
        self.assertEqual([tuple(s) for s in stances],
                         [("bedrock-openai-blog@2026-09-24", "contradicts")])

    def test_unpublished_platform_currency_has_no_conversion(self) -> None:
        hit = price_at(self.db, channel_id="databricks", label="claude-opus-5-5",
                       at=NOW, price_unit_id="databricks-dbu")
        self.assertEqual(hit["rates"]["input"], "57.143")
        self.assertEqual(unit_value_at(self.db, unit_id="databricks-dbu",
                                       target_unit_id="USD", at=NOW,
                                       channel_id="databricks"), [])


if __name__ == "__main__":
    unittest.main()
