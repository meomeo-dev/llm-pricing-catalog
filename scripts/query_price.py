import argparse
import json
import shlex
import sqlite3
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

import model_search

ROOT = Path(__file__).resolve().parent.parent
PRICE_AT = ROOT / "schema" / "queries" / "price_at.sql"
DEFAULT_DATABASE = ROOT / "build" / "catalog.sqlite"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="按时点查询一个模型在某渠道的单价")
    parser.add_argument("label", help="模型名：规范 ID、渠道的模型 ID 或显示名、客户端标签")
    parser.add_argument("--channel", help="渠道 ID；缺省为模型厂商自己的 API")
    parser.add_argument("--client", help="客户端 ID：按客户端的别名与参考渠道解析")
    parser.add_argument("--at", help="时点，YYYY-MM-DD 或 YYYY-MM-DDTHH:MM:SSZ；缺省为现在")
    parser.add_argument("--known-at", help="只看该时刻已录入的数据，用于回放当时的认知")
    parser.add_argument("--tier", help="服务档，如 standard、batch、fast；缺省取名字隐含的服务档，"
                        "没有则为 standard")
    parser.add_argument("--region", default="global", help="地域范围，如 global、us；"
                        "缺省为 global")
    parser.add_argument("--unit", help="计价单位，如 USD、kiro-credit；缺省接受渠道唯一的"
                        "计价单位")
    parser.add_argument("--plan", help="套餐 ID")
    parser.add_argument("--variant", help="托管变体")
    parser.add_argument("--window", help="计价时段 ID")
    parser.add_argument("--commitment", help="承诺期限")
    parser.add_argument("--upstream", help="上游供给 ID（中转或路由的价格系列）")
    parser.add_argument("--input-tokens", type=int, help="单次请求输入 token 数，用于长上下文阶梯")
    parser.add_argument("--db", type=Path, default=DEFAULT_DATABASE, help="目录库路径")
    parser.add_argument("--json", action="store_true", help="以 JSON 输出")
    parser.add_argument("--search", action="store_true",
                        help="不查价，只按名字搜索各渠道与客户端里的模型名（含曾用名）")
    return parser.parse_args()


def utc_instant(value: str | None) -> str | None:
    if value is None:
        return None
    if len(value) == len("YYYY-MM-DD"):
        return f"{value}T00:00:00Z"
    datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    return value


def query_parameters(args: argparse.Namespace) -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "label": args.label, "channel_id": args.channel, "client_id": args.client,
        "at": utc_instant(args.at) or now, "known_at": utc_instant(args.known_at),
        "service_tier": args.tier, "region_id": args.region, "price_unit_id": args.unit,
        "plan_id": args.plan, "variant": args.variant, "window_id": args.window,
        "commitment_term": args.commitment, "upstream_offering_id": args.upstream,
        "input_tokens": args.input_tokens,
    }


CARD_DETAIL = """
SELECT c.price_card_id, o.model_id, o.channel_id, c.valid_from, c.valid_to, c.date_basis,
       s.service_tier, s.region_id, s.price_unit_id, src.url AS source_url
  FROM price_card c
  JOIN price_series s ON s.price_series_id = c.price_series_id
  JOIN offering o ON o.offering_id = s.offering_id
  JOIN source src ON src.source_id = c.source_id
 WHERE c.price_card_id = ?
"""


def lookup(connection: sqlite3.Connection, parameters: dict) -> list[dict]:
    rows = connection.execute(PRICE_AT.read_text(encoding="utf-8"), parameters).fetchall()
    cards: dict[int, dict] = {}
    for row in rows:
        card = cards.get(row["price_card_id"])
        if card is None:
            detail = connection.execute(CARD_DETAIL, (row["price_card_id"],)).fetchone()
            card = cards[row["price_card_id"]] = {**dict(detail), "rates": []}
        meter = connection.execute("SELECT per_quantity, quantity_unit FROM meter"
                                   " WHERE meter_id = ?", (row["meter_id"],)).fetchone()
        card["rates"].append({"meter_id": row["meter_id"], "amount": row["amount"],
                              "per_quantity": meter["per_quantity"],
                              "quantity_unit": meter["quantity_unit"]})
    return list(cards.values())


SERIES_OF_MODELS = """
SELECT DISTINCT o.model_id, o.channel_id, s.service_tier, s.region_id, s.price_unit_id,
       o.variant, s.plan_id, s.upstream_offering_id, s.window_id, s.commitment_term
  FROM price_card c
  JOIN price_series s ON s.price_series_id = c.price_series_id
  JOIN offering o ON o.offering_id = s.offering_id
 WHERE o.model_id IN (SELECT value FROM json_each(:models))
   AND (json_array_length(:channels) = 0
        OR o.channel_id IN (SELECT value FROM json_each(:channels)))
   AND c.valid_from <= :at AND (c.valid_to IS NULL OR :at < c.valid_to)
   AND c.recorded_at <= coalesce(:known_at, '9999-12-31T00:00:00Z')
   AND (c.superseded_at IS NULL
        OR c.superseded_at > coalesce(:known_at, '9999-12-31T00:00:00Z'))
 ORDER BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
"""
SERIES_HEADER = ("模型", "渠道", "服务档", "地域", "计价单位", "其他参数")
EXTRA_OPTIONS = (("variant", "--variant"), ("plan_id", "--plan"),
                 ("upstream_offering_id", "--upstream"), ("window_id", "--window"),
                 ("commitment_term", "--commitment"))


def available_series(connection: sqlite3.Connection, models: list[str],
                     channels: list[str], parameters: dict) -> list[tuple]:
    rows = connection.execute(SERIES_OF_MODELS, {
        "models": json.dumps(models), "channels": json.dumps(channels),
        "at": parameters["at"], "known_at": parameters["known_at"]})
    series = []
    for row in rows:
        extra = " ".join(f"{flag} {row[column]}" for column, flag in EXTRA_OPTIONS
                         if row[column])
        series.append((row["model_id"], row["channel_id"], row["service_tier"],
                       row["region_id"], row["price_unit_id"], extra))
    return series


def display_width(text: str) -> int:
    return sum(2 if unicodedata.east_asian_width(char) in "WF" else 1 for char in text)


def print_table(rows: list[tuple]) -> None:
    widths = [max(display_width(str(cell)) for cell in column)
              for column in zip(SERIES_HEADER, *rows)]
    for row in (SERIES_HEADER, *rows):
        cells = [str(cell) + " " * (width - display_width(str(cell)))
                 for cell, width in zip(row, widths)]
        print("  " + "  ".join(cells).rstrip(), file=sys.stderr)


def example_command(row: tuple, series: list[tuple]) -> str:
    model, channel, tier, region, unit, extra = row
    flags = []
    if tier != "standard":
        flags.append(f"--tier {tier}")
    if region != "global":
        flags.append(f"--region {region}")
    units = {other[4] for other in series if other[:4] == row[:4] and other[5] == extra}
    if len(units) > 1:
        flags.append(f"--unit {unit}")
    return " ".join(["python3 scripts/query_price.py", model, "--channel", channel,
                     *flags, extra]).rstrip()


def describe_name(name: dict) -> str:
    where = name["channel_id"] or name["client_id"] or "目录"
    period = "现行" if name["is_current"] else f"{name['valid_from']}–{name['valid_to']}"
    return (f"{name['identifier']}  [{name['kind']}，{where}，{period}] → {name['model_id']}"
            f"（{model_search.MATCH_LEVELS[name['match_level']]}）")


def print_suggestions(connection: sqlite3.Connection, names: list[dict],
                      channels: list[str], parameters: dict) -> None:
    print("没有命中的价目卡。", file=sys.stderr)
    models = sorted({name["model_id"] for name in model_search.priceable_matches(names)})
    if not models:
        print_candidates(names)
        return
    series = available_series(connection, models, channels, parameters)
    if not series and channels:
        series = available_series(connection, models, [], parameters)
        if series:
            print(f"{'、'.join(models)} 在 {'、'.join(channels)} 没有 {parameters['at']}"
                  " 时的价格；其他渠道有：", file=sys.stderr)
    if not series:
        print(f"{'、'.join(models)} 在 {parameters['at']} 没有任何价格。", file=sys.stderr)
        return
    print("可查的组合：", file=sys.stderr)
    print_table(series)
    print(f"例：{example_command(series[0], series)}", file=sys.stderr)


def print_candidates(names: list[dict]) -> None:
    closest = model_search.closest_matches(names)
    if not closest:
        print("目录里没有相近的模型名。", file=sys.stderr)
        return
    if closest[0]["match_level"] == model_search.STRIPPED_PREFIX_LEVEL:
        print("没有与它相同的模型名；省掉前缀后相同的有：", file=sys.stderr)
        for name in closest:
            print(f"  {describe_name(name)}", file=sys.stderr)
        example = shlex.quote(closest[0]["identifier"])
    else:
        models = model_search.candidate_models(names)
        print("名字不能确定是哪个模型，包含它的有（--search 看各渠道的写法）：",
              file=sys.stderr)
        for model in models:
            print(f"  {model}", file=sys.stderr)
        example = models[0]
    print(f"例：python3 scripts/query_price.py {example}", file=sys.stderr)


def print_cards(cards: list[dict]) -> None:
    for card in cards:
        period = f"{card['valid_from']} 起" + (f"，至 {card['valid_to']}" if card["valid_to"]
                                               else "")
        print(f"{card['model_id']} @ {card['channel_id']}"
              f"（{card['service_tier']}，{card['region_id']}，{card['price_unit_id']}）")
        print(f"  有效期：{period}（依据 {card['date_basis']}）")
        print(f"  来源：{card['source_url']}")
        for rate in card["rates"]:
            print(f"  {rate['meter_id']:<18} {rate['amount']:>10} {card['price_unit_id']}"
                  f" / {rate['per_quantity']:,} {rate['quantity_unit']}")


def main() -> int:
    args = parse_args()
    if not args.db.is_file():
        print(f"找不到目录库 {args.db}；先运行 python3 scripts/build_catalog.py", file=sys.stderr)
        return 1
    connection = sqlite3.connect(args.db)
    connection.row_factory = sqlite3.Row
    parameters = query_parameters(args)
    if args.search:
        return print_names(model_search.find_names(
            connection, args.label, parameters["at"], args.channel), args.json)
    cards = lookup(connection, parameters)
    if not cards:
        names = model_search.find_names(connection, args.label, parameters["at"])
        cards, channels = lookup_resolved(connection, parameters, names, args)
        if not cards:
            print_suggestions(connection, names, channels, parameters)
            return 1
    if args.json:
        print(json.dumps(cards, ensure_ascii=False, indent=2))
    else:
        print_cards(cards)
    return 0


def lookup_resolved(connection: sqlite3.Connection, parameters: dict, names: list[dict],
                    args: argparse.Namespace) -> tuple[list[dict], list[str]]:
    targets, note = model_search.resolve_targets(names, args.label, args.channel,
                                                 args.client)
    if note:
        print(note, file=sys.stderr)
    cards: dict[int, dict] = {}
    for target in targets:
        for card in lookup(connection, {**parameters, **target}):
            cards.setdefault(card["price_card_id"], card)
    channels = sorted({target["channel_id"] for target in targets if target.get("channel_id")})
    return list(cards.values()), channels or ([args.channel] if args.channel else [])


def print_names(names: list[dict], as_json: bool) -> int:
    if as_json:
        print(json.dumps(names, ensure_ascii=False, indent=2))
    else:
        for name in names:
            print(describe_name(name))
    return 0 if names else 1


if __name__ == "__main__":
    sys.exit(main())
