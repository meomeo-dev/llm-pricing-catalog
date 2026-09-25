import subprocess
import tomllib
from pathlib import Path

from catalog_build.expand import Entry, EntryError

DEFAULTS_KEY = "defaults"


def parse(text: str, name: str) -> list[Entry]:
    try:
        document = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise EntryError(f"{name}：TOML 语法错误：{error}") from error
    defaults = document.pop(DEFAULTS_KEY, {})
    entries = []
    for kind, items in document.items():
        if not isinstance(items, list):
            raise EntryError(f"{name}：顶层键 {kind} 必须是条目数组 [[{kind}]]")
        for index, values in enumerate(items, start=1):
            entries.append(Entry(kind, values, defaults, f"{name}#{kind}[{index}]"))
    return entries


def working_tree_entries(data_dir: Path) -> list[Entry]:
    entries = []
    for path in sorted(data_dir.rglob("*.toml")):
        name = str(path.relative_to(data_dir.parent))
        entries += parse(path.read_text(encoding="utf-8"), name)
    return entries


def revision_entries(root: Path, revision: str, data_dir_name: str) -> list[Entry]:
    listing = subprocess.run(
        ["git", "-C", str(root), "ls-tree", "-r", "--name-only", revision,
         f"{data_dir_name}/"], capture_output=True, text=True, check=True).stdout
    entries = []
    for name in sorted(line for line in listing.splitlines() if line.endswith(".toml")):
        text = subprocess.run(["git", "-C", str(root), "show", f"{revision}:{name}"],
                              capture_output=True, text=True, check=True).stdout
        entries += parse(text, f"{revision}:{name}")
    return entries
