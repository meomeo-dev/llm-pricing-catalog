import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from catalog_build import database, entries
from catalog_build.expand import EntryError, expand

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schema"
DEFAULT_DATA_DIR = ROOT / "data"
DEFAULT_TARGET = ROOT / "build" / "catalog.sqlite"


def expand_all(entry_list: list) -> list:
    return [row for entry in entry_list for row in expand(entry)]


def build(data_dir: Path, target: str):
    connection = database.open_schema(SCHEMA_DIR, target)
    by_table, supersedes = database.collect(
        connection, expand_all(entries.working_tree_entries(data_dir)))
    database.insert_all(connection, by_table)
    database.apply_supersedes(connection, supersedes)
    return connection, by_table, supersedes


def check_append_only(revision: str, data_dir: Path, by_table: dict,
                      supersedes: list) -> None:
    fresh = database.open_schema(SCHEMA_DIR)
    seeded = {t: database.stored_keys(fresh, t) for t in database.table_order(fresh)}
    old_rows = expand_all(entries.revision_entries(ROOT, revision, data_dir.name))
    old_by_table, old_supersedes = database.collect(fresh, old_rows)
    database.insert_all(fresh, old_by_table)
    database.apply_supersedes(fresh, old_supersedes)
    database.replay(fresh, by_table, supersedes, seeded)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="从 schema/ 与 data/ 构建目录数据库，并校验不变量与只增不改")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--against", help="只增不改检查的对照 git 版本")
    args = parser.parse_args()
    args.target.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.target.with_suffix(".tmp")
    if temporary.exists():
        temporary.replace(args.target.with_suffix(".stale"))
    try:
        connection, by_table, supersedes = build(args.data, str(temporary))
        if args.against:
            check_append_only(args.against, args.data, by_table, supersedes)
    except (EntryError, database.BuildError) as error:
        print(f"构建失败：{error}", file=sys.stderr)
        return 1
    found = database.violations(connection)
    for view, rows in found.items():
        print(f"不变量 {view} 非空，共 {len(rows)} 行，前 5 行：{rows[:5]}",
              file=sys.stderr)
    connection.commit()
    connection.close()
    if found:
        return 1
    temporary.replace(args.target)
    counts = {t: len(rows) for t, rows in by_table.items()}
    shown = (args.target.relative_to(ROOT) if args.target.resolve().is_relative_to(ROOT)
             else args.target)
    print(f"已写入 {shown}：{counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
