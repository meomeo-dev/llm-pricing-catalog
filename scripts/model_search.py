import sqlite3

MATCH_LEVELS = {1: "原文相同", 2: "写法归一后相同", 3: "去掉前缀后相同", 4: "包含"}
PRICEABLE_LEVEL, STRIPPED_PREFIX_LEVEL = 2, 3
SEARCH = """
SELECT *, CASE
            WHEN identifier = :term THEN 1
            WHEN identifier_key = :key THEN 2
            WHEN identifier_key LIKE '%/' || :key OR identifier_key LIKE '%-' || :key THEN 3
            ELSE 4
          END AS match_level,
       (valid_from IS NULL OR valid_from <= :now)
         AND (valid_to IS NULL OR :now < valid_to) AS is_current
  FROM model_identifier_lookup
 WHERE instr(identifier_key, :key) > 0
   AND (:channel IS NULL OR channel_id = :channel)
 ORDER BY match_level, is_current DESC, model_id, namespace_kind, channel_id, client_id,
          valid_from
"""


def identifier_key(text: str) -> str:
    return text.replace(" ", "-").replace("_", "-").replace(".", "-").lower()


def find_names(connection: sqlite3.Connection, term: str, now: str,
               channel: str | None = None) -> list[dict]:
    parameters = {"term": term, "key": identifier_key(term), "now": now,
                  "channel": channel}
    cursor = connection.execute(SEARCH, parameters)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def closest_matches(names: list[dict]) -> list[dict]:
    current = [name for name in names if name["is_current"]]
    if not current:
        return []
    best = min(name["match_level"] for name in current)
    return [name for name in current if name["match_level"] == best]


def priceable_matches(names: list[dict]) -> list[dict]:
    closest = closest_matches(names)
    if closest and closest[0]["match_level"] <= PRICEABLE_LEVEL:
        return closest
    return []


def candidate_models(names: list[dict]) -> list[str]:
    levels: dict[str, int] = {}
    for name in names:
        if name["is_current"]:
            best = levels.get(name["model_id"], name["match_level"])
            levels[name["model_id"]] = min(best, name["match_level"])
    return sorted(levels, key=lambda model: (levels[model], model))


def resolve_targets(names: list[dict], term: str, channel_id: str | None,
                    client_id: str | None) -> tuple[list[dict], str]:
    top = priceable_matches(names)
    models = sorted({name["model_id"] for name in top})
    if len(models) > 1:
        return [], f"{term} 对应多个模型：{'、'.join(models)}，请写得更具体"
    if not models:
        return [], ""
    model, level = models[0], MATCH_LEVELS[top[0]["match_level"]]
    scoped = sorted({name["identifier"] for name in top
                     if (channel_id and name["channel_id"] == channel_id)
                     or (client_id and name["client_id"] == client_id)})
    channel_names = sorted({(name["channel_id"], name["identifier"]) for name in top
                            if name["channel_id"]})
    own_name = any(name["namespace_kind"] == "catalog" for name in top)
    note = f"{term} 解析为 {model}（{level}）"
    if scoped:
        targets = [{"label": identifier} for identifier in scoped]
    elif channel_id or client_id or own_name or not channel_names:
        targets = [{"label": model}]
    else:
        channels = list(dict.fromkeys(channel for channel, _ in channel_names))
        note = f"{term} 是 {'、'.join(channels)} 的模型名（{model}，{level}）"
        if len(channels) > 1:
            note += "，分别列出；用 --channel 只看一个"
        targets = [{"label": identifier, "channel_id": channel}
                   for channel, identifier in channel_names]
    already_queried = (term, channel_id)
    targets = [target for target in targets
               if (target["label"], target.get("channel_id", channel_id))
               != already_queried]
    return targets, (note if targets else "")
