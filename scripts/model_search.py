import sqlite3

MATCH_LEVELS = {1: "原文相同", 2: "写法归一后相同", 3: "去掉渠道前缀后相同", 4: "包含"}
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
 LIMIT :limit
"""


def identifier_key(text: str) -> str:
    return text.replace(" ", "-").replace("_", "-").replace(".", "-").lower()


def find_names(connection: sqlite3.Connection, term: str, now: str,
               channel: str | None = None, limit: int = 50) -> list[dict]:
    parameters = {"term": term, "key": identifier_key(term), "now": now,
                  "channel": channel, "limit": limit}
    cursor = connection.execute(SEARCH, parameters)
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def sole_channel(names: list[dict]) -> str | None:
    channels = {name["channel_id"] for name in names
                if name["match_level"] == 1 and name["is_current"] and name["channel_id"]}
    return next(iter(channels)) if len(channels) == 1 else None
