import sqlite3
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schema"
TARGET = SCHEMA_DIR / "08_append_only.sql"
TABLE_METADATA = SCHEMA_DIR / "tables.toml"
TABLE_SOURCES = ("01_parties.sql", "02_models_offerings.sql", "03_commerce.sql",
                 "04_prices.sql")
SUPERSEDE_COLUMNS = ("superseded_at", "supersede_reason")
HEADER = """\
-- 只增不改：由 scripts/gen_append_only.py 从 DDL 与 schema/tables.toml 生成，请勿手工编辑。
-- SCD2 版本表只允许补写一次 superseded_at 与 supersede_reason；
-- 身份表只允许改写 schema/tables.toml 中声明为 Type 1 的描述列；任何表都不允许删除。
"""


def type1_columns_by_table(tables: list[str]) -> dict[str, list[str]]:
    metadata = tomllib.loads(TABLE_METADATA.read_text(encoding="utf-8"))
    if set(metadata) != set(tables):
        sys.exit(f"{TABLE_METADATA.name} 与 DDL 的表不一致："
                 f"缺 {sorted(set(tables) - set(metadata))}，"
                 f"多 {sorted(set(metadata) - set(tables))}")
    return {table: entry.get("type1", []) for table, entry in metadata.items()}


def data_columns(connection: sqlite3.Connection, table: str) -> list[str]:
    rows = connection.execute(f"PRAGMA table_xinfo({table})").fetchall()
    return [row[1] for row in rows if row[6] == 0]


def changed_any(columns: list[str]) -> str:
    return "\n     OR ".join(f"OLD.{column} IS NOT NEW.{column}" for column in columns)


def update_trigger(table: str, columns: list[str], type1: list[str]) -> str:
    if "superseded_at" in columns:
        frozen = [c for c in columns if c not in SUPERSEDE_COLUMNS]
        condition = ("OLD.superseded_at IS NOT NULL\n     OR NEW.superseded_at IS NULL"
                     f"\n     OR {changed_any(frozen)}")
        message = f"{table}：版本行只允许补写一次 superseded_at 与 supersede_reason"
    else:
        frozen = [c for c in columns if c not in type1]
        condition = changed_any(frozen)
        allowed = "、".join(type1) if type1 else "无"
        message = f"{table}：只允许改写 Type 1 列（{allowed}）"
    return (f"CREATE TRIGGER {table}_no_update BEFORE UPDATE ON {table}\n"
            f"  WHEN {condition}\n"
            f"BEGIN SELECT RAISE(ABORT, '{message}'); END;\n")


def delete_trigger(table: str) -> str:
    return (f"CREATE TRIGGER {table}_no_delete BEFORE DELETE ON {table}\n"
            f"BEGIN SELECT RAISE(ABORT, '{table}：不允许删除，请以新版本或更正代替'); END;\n")


def render() -> str:
    ddl = "\n".join((SCHEMA_DIR / name).read_text(encoding="utf-8")
                    for name in TABLE_SOURCES)
    connection = sqlite3.connect(":memory:")
    connection.executescript(ddl)
    tables = [row[0] for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY rowid")]
    type1 = type1_columns_by_table(tables)
    blocks = [HEADER]
    for table in tables:
        columns = data_columns(connection, table)
        unknown = set(type1.get(table, [])) - set(columns)
        if unknown:
            sys.exit(f"{table} 的 Type 1 声明引用了不存在的列：{sorted(unknown)}")
        blocks.append(f"\n-- {table}\n")
        blocks.append(update_trigger(table, columns, type1.get(table, [])))
        blocks.append(delete_trigger(table))
    return "".join(blocks)


def main() -> None:
    generated = render()
    if "--check" in sys.argv:
        current = TARGET.read_text(encoding="utf-8") if TARGET.exists() else ""
        if current != generated:
            sys.exit(f"{TARGET.name} 与 DDL 或 {TABLE_METADATA.name} 不一致，"
                     "请运行 scripts/gen_append_only.py")
        return
    TARGET.write_text(generated, encoding="utf-8")
    print(f"已写入 {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
