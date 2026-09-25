import html
import shutil
import sqlite3
import subprocess
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schema"
OUT_DIR = ROOT / "docs" / "model"

SCD2_COLUMNS = ("valid_from", "valid_to", "date_basis", "recorded_at",
                "superseded_at", "supersede_reason")

LAYERS = (
    ("参与方与计量", "#EEF4FF", "#4C6EF5",
     ("organization", "region", "channel", "client", "label_namespace", "billing_unit",
      "meter", "time_window")),
    ("模型与供给", "#EBFBEE", "#37B24D",
     ("model", "model_revision", "model_revision_modality", "model_revision_effort",
      "client_revision", "model_identifier", "offering", "offering_revision",
      "offering_route")),
    ("商业条款", "#E6FCF5", "#0CA678",
     ("plan", "plan_revision", "plan_revision_client", "plan_allowance",
      "unit_rate_series", "unit_rate", "pricing_rule", "pricing_rule_revision",
      "pricing_rule_scope_model", "pricing_rule_scope_meter")),
    ("价格维度", "#FFF4E6", "#F76707",
     ("price_series", "price_card", "price_rate", "price_evidence")),
    ("证据与缺口", "#F8F0FC", "#AE3EC9", ("source", "price_gap")),
)

MANDATORY_CHILDREN = {("price_rate", "price_card"), ("price_card", "price_series")}
FONT = "PingFang SC"
RANKDIR = "TB"


def table_titles() -> dict:
    metadata = tomllib.loads((SCHEMA_DIR / "tables.toml").read_text(encoding="utf-8"))
    return {table: entry["title"] for table, entry in metadata.items()}


def describe(connection: sqlite3.Connection, table: str) -> tuple:
    columns = connection.execute(f"PRAGMA table_xinfo({table})").fetchall()
    foreign_keys = connection.execute(f"PRAGMA foreign_key_list({table})").fetchall()
    links = {row[3]: row[2] for row in foreign_keys}
    return columns, links


def column_row(column: tuple, links: dict) -> str:
    _, name, col_type, not_null, _, pk, hidden = column
    badge = "PK" if pk else ("FK" if name in links else "")
    if hidden:
        badge = "GEN"
    color = {"PK": "#C92A2A", "FK": "#1971C2", "GEN": "#868E96"}.get(badge)
    badge_cell = f'<FONT COLOR="{color}">{badge}</FONT>' if badge else ""
    optional = "" if (not_null or pk) else "?"
    return (
        f'<TR><TD ALIGN="LEFT">{badge_cell}</TD>'
        f'<TD ALIGN="LEFT" PORT="{name}">{html.escape(name)}{optional}</TD>'
        f'<TD ALIGN="LEFT"><FONT COLOR="#868E96">{col_type.lower()}</FONT></TD></TR>'
    )


def node_label(table: str, title: str, columns: list, links: dict, color: str) -> str:
    names = {column[1] for column in columns}
    has_scd2 = all(name in names for name in SCD2_COLUMNS)
    rows = [column_row(column, links) for column in columns
            if not (has_scd2 and column[1] in SCD2_COLUMNS)]
    if has_scd2:
        rows.append(
            '<TR><TD></TD><TD ALIGN="LEFT" COLSPAN="2"><FONT COLOR="#2B8A3E">'
            '<I>SCD2：valid_from · valid_to · date_basis<BR ALIGN="LEFT"/>'
            'recorded_at · superseded_at · supersede_reason</I></FONT></TD></TR>')
    header = (f'<TR><TD COLSPAN="3" BGCOLOR="{color}"><FONT COLOR="white">'
              f'<B>{table}</B>  {html.escape(title)}</FONT></TD></TR>')
    return ('<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3">'
            + header + "".join(rows) + "</TABLE>>")


def edge(child: str, column: str, parent: str, nullable: bool) -> str:
    many = "crowtee" if (child, parent) in MANDATORY_CHILDREN else "crowodot"
    one = "teeodot" if nullable else "teetee"
    style = ('style=dashed, color="#BE4BDB80", constraint=false' if parent == "source"
             else 'color="#495057"')
    label = "" if parent == "source" else f', label="{column}"'
    return (f'  {child} -> {parent} '
            f'[dir=both, arrowtail={many}, arrowhead={one}, {style}{label}];')


def build_dot(connection: sqlite3.Connection, titles: dict) -> str:
    lines = [
        "digraph catalog {",
        f'  graph [rankdir={RANKDIR}, newrank=true, splines=spline, nodesep=0.5,'
        f' ranksep=0.9,'
        f' fontname="{FONT}", label="llm-pricing-catalog ER 模型（由 schema/*.sql'
        f' 生成）", labelloc=t, fontsize=20, pad=0.3];',
        f'  node [shape=plain, fontname="{FONT}", fontsize=11];',
        f'  edge [fontname="{FONT}", fontsize=10, fontcolor="#495057",'
        f' arrowsize=0.9];',
    ]
    edges = []
    for index, (layer, fill, border, tables) in enumerate(LAYERS):
        lines.append(f"  subgraph cluster_{index} {{")
        lines.append(f'    label="{layer}"; style="rounded,filled"; fillcolor="{fill}";'
                     f' color="{border}"; fontsize=14;')
        for table in tables:
            columns, links = describe(connection, table)
            label = node_label(table, titles.get(table, ""), columns, links, border)
            lines.append(f"    {table} [label={label}];")
            not_null = {column[1]: column[3] for column in columns}
            edges += [edge(table, column, parent, not not_null[column])
                      for column, parent in links.items()]
        lines.append("  }")
    return "\n".join(lines + edges + ["}"]) + "\n"


def main() -> None:
    ddl = "\n".join(path.read_text(encoding="utf-8")
                    for path in sorted(SCHEMA_DIR.glob("*.sql")))
    connection = sqlite3.connect(":memory:")
    connection.executescript(ddl)
    all_tables = {row[0] for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table'")}
    drawn = {table for *_, tables in LAYERS for table in tables}
    if all_tables != drawn:
        raise SystemExit(f"分层表与 DDL 不一致：缺 {all_tables - drawn}，多 {drawn - all_tables}")
    dot_path = OUT_DIR / "er-model.dot"
    dot_path.write_text(build_dot(connection, table_titles()), encoding="utf-8")
    if shutil.which("dot") is None:
        raise SystemExit("未找到 Graphviz 的 dot 命令，只生成了 .dot 文件")
    for fmt in ("svg", "png"):
        extra = ["-Gdpi=144"] if fmt == "png" else []
        subprocess.run(["dot", f"-T{fmt}", *extra, str(dot_path),
                        "-o", str(dot_path.with_suffix(f".{fmt}"))], check=True)
    print(f"已生成 {dot_path.relative_to(ROOT)} 及 svg、png")


if __name__ == "__main__":
    main()
