import sqlite3
from pathlib import Path

from catalog_build import keys
from catalog_build.expand import Row

SUPERSEDE = "__supersede__"


class BuildError(RuntimeError):
    pass


def open_schema(schema_dir: Path, target: str = ":memory:") -> sqlite3.Connection:
    connection = sqlite3.connect(target)
    for script in sorted(schema_dir.glob("*.sql")):
        connection.executescript(script.read_text(encoding="utf-8"))
    return connection


def table_order(connection: sqlite3.Connection) -> list[str]:
    return [row[0] for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY rowid")]


def primary_key(connection: sqlite3.Connection, table: str) -> tuple[str, ...]:
    info = connection.execute(f"PRAGMA table_info({table})").fetchall()
    return tuple(row[1] for row in sorted(info, key=lambda r: r[5]) if row[5] > 0)


def collect(connection: sqlite3.Connection, rows: list[Row]) -> tuple[dict, list]:
    by_table: dict[str, dict[tuple, Row]] = {}
    supersedes = [row for row in rows if row.table == SUPERSEDE]
    for row in rows:
        if row.table == SUPERSEDE:
            continue
        key = tuple(row.values.get(c) for c in primary_key(connection, row.table))
        seen = by_table.setdefault(row.table, {}).get(key)
        if seen is not None and seen.values != row.values:
            raise BuildError(f"{row.table} {key} 有两种写法：{seen.origin} 与 {row.origin}")
        by_table[row.table].setdefault(key, row)
    return by_table, supersedes


def insert(connection: sqlite3.Connection, row: Row) -> None:
    columns = ", ".join(row.values)
    placeholders = ", ".join(f":{column}" for column in row.values)
    try:
        connection.execute(f"INSERT INTO {row.table} ({columns}) VALUES ({placeholders})",
                           row.values)
    except sqlite3.Error as error:
        raise BuildError(f"{row.origin}：写入 {row.table} 失败：{error}") from error


def ordered_rows(table: str, rows: list[Row]) -> list[Row]:
    if table != "price_card":
        return rows
    return sorted(rows, key=lambda row: "derived_from_card_id" in row.values)


def insert_all(connection: sqlite3.Connection, by_table: dict) -> None:
    for table in table_order(connection):
        for row in ordered_rows(table, list(by_table.get(table, {}).values())):
            insert(connection, row)


def apply_supersedes(connection: sqlite3.Connection, supersedes: list[Row]) -> None:
    for row in supersedes:
        target = row.values
        column = keys.SURROGATE_COLUMN[target["table"]]
        current = connection.execute(
            f"SELECT superseded_at, supersede_reason FROM {target['table']}"
            f" WHERE {column} = ?", (target["row_id"],)).fetchone()
        if current is None:
            raise BuildError(f"{row.origin}：找不到被更正的 {target['table']} 行")
        if current == (target["superseded_at"], target["supersede_reason"]):
            continue
        try:
            connection.execute(
                f"UPDATE {target['table']} SET superseded_at = ?, supersede_reason = ?"
                f" WHERE {column} = ?",
                (target["superseded_at"], target["supersede_reason"], target["row_id"]))
        except sqlite3.Error as error:
            raise BuildError(f"{row.origin}：更正失败：{error}") from error


def violations(connection: sqlite3.Connection) -> dict[str, list[tuple]]:
    views = [row[0] for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type = 'view'"
        " AND name LIKE 'v\\_%' ESCAPE '\\' ORDER BY name")]
    found = {view: [tuple(r) for r in connection.execute(f"SELECT * FROM {view}")]
             for view in views}
    return {view: rows for view, rows in found.items() if rows}


def overwrite(connection: sqlite3.Connection, row: Row, pk_columns: tuple,
              key: tuple) -> None:
    where = " AND ".join(f"{c} IS :__pk{i}" for i, c in enumerate(pk_columns))
    params = {**row.values, **{f"__pk{i}": value for i, value in enumerate(key)}}
    stored = connection.execute(
        f"SELECT {', '.join(row.values)} FROM {row.table} WHERE {where}", params)
    if stored.fetchone() == tuple(row.values.values()):
        return
    assignments = ", ".join(f"{c} = :{c}" for c in row.values)
    try:
        connection.execute(f"UPDATE {row.table} SET {assignments} WHERE {where}", params)
    except sqlite3.Error as error:
        raise BuildError(f"{row.origin}：改写了历史行：{error}") from error


def stored_keys(connection: sqlite3.Connection, table: str) -> set[tuple]:
    columns = ", ".join(primary_key(connection, table))
    return {tuple(r) for r in connection.execute(f"SELECT {columns} FROM {table}")}


def replay(connection: sqlite3.Connection, by_table: dict, supersedes: list,
           seeded: dict[str, set]) -> None:
    for table in table_order(connection):
        current = by_table.get(table, {})
        pk_columns = primary_key(connection, table)
        stored = stored_keys(connection, table)
        deleted = stored - set(current) - seeded.get(table, set())
        if deleted:
            raise BuildError(f"{table} 的历史行被删除，共 {len(deleted)} 行，"
                             f"前 5 行：{sorted(deleted)[:5]}")
        for key, row in current.items():
            if key in stored:
                overwrite(connection, row, pk_columns, key)
            else:
                insert(connection, row)
    apply_supersedes(connection, supersedes)
