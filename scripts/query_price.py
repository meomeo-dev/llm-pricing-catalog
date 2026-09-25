import argparse
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRICE_AT = ROOT / "schema" / "queries" / "price_at.sql"
DEFAULT_DATABASE = ROOT / "build" / "catalog.sqlite"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="按时点查询一个模型在某渠道的单价")
    parser.add_argument("label", help="模型 ID 或别名，如 claude-opus-5-5")
    parser.add_argument("--channel", help="渠道 ID；缺省为模型厂商自己的 API")
    parser.add_argument("--client", help="客户端 ID：按客户端的别名与参考渠道解析")
    parser.add_argument("--at", help="时点，YYYY-MM-DD 或 YYYY-MM-DDTHH:MM:SSZ；缺省为现在")
    parser.add_argument("--known-at", help="只看该时刻已录入的数据，用于回放当时的认知")
    parser.add_argument("--tier", default="standard", help="服务档，如 standard、batch")
    parser.add_argument("--region", default="global", help="地域范围，如 global、us")
    parser.add_argument("--unit", default="USD", help="计价单位，如 USD、credit")
    parser.add_argument("--plan", help="套餐 ID")
    parser.add_argument("--variant", help="托管变体")
    parser.add_argument("--window", help="计价时段 ID")
    parser.add_argument("--commitment", help="承诺期限")
    parser.add_argument("--upstream", help="上游供给 ID（中转或路由的价格系列）")
    parser.add_argument("--input-tokens", type=int, help="单次请求输入 token 数，用于长上下文阶梯")
    parser.add_argument("--db", type=Path, default=DEFAULT_DATABASE, help="目录库路径")
    parser.add_argument("--json", action="store_true", help="以 JSON 输出")
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
SELECT o.model_id, o.channel_id, c.valid_from, c.valid_to, c.date_basis,
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


def available_series(connection: sqlite3.Connection, label: str,
                     channel: str | None) -> list[tuple]:
    return connection.execute(
        "SELECT DISTINCT channel_id, service_tier, region_id, price_unit_id"
        "  FROM price_current WHERE model_id = ? AND (? IS NULL OR channel_id = ?)"
        " ORDER BY 1, 2, 3, 4", (label, channel, channel)).fetchall()


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
    cards = lookup(connection, query_parameters(args))
    if not cards:
        print("没有命中的价目卡。该模型当前的（渠道, 服务档, 地域, 计价单位）组合：",
              file=sys.stderr)
        for series in available_series(connection, args.label, args.channel):
            print(f"  {tuple(series)}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(cards, ensure_ascii=False, indent=2))
    else:
        print_cards(cards)
    return 0


if __name__ == "__main__":
    sys.exit(main())
