# llm-pricing-catalog

LLM 调用价格的历史目录。能回答"某模型在某渠道、某时刻的单价是多少，出处是哪一页"。

- 按缓慢变化维度第 2 型（SCD2）记录全部变化，可查询任意历史时刻的价格。
- 额外记录每一行的录入与更正时间，可回放已撤销的预告价；历史行只增不改，由触发器强制。
- 每条价格都挂来源：URL、抓取时间与内容哈希（sha256）。
- 同时记录模型元信息：上下文窗口、最大输出、知识截止、强度档、生命周期。
- 模型支持厂商、云平台、企业平台、聚合商、中转站与工具内置等渠道，记录运营方、卖方、
  开票方、上游路由与可信度。当前数据收录 Claude、GPT、Gemini 在厂商 API、云平台、
  聚合商与工具订阅中的价格。
- 价格可以用法币、平台货币、积分、请求次数或相对倍率计，单位价值另行记录并可换算。

## 目录

| 路径 | 内容 |
|---|---|
| `schema/*.sql` | ER 模型的权威定义（SQLite），按文件名顺序加载 |
| `schema/tables.toml` | 每张表的中文名、粒度与 Type 1 列 |
| `schema/08_append_only.sql` | 只增不改触发器，由 `scripts/gen_append_only.py` 从 DDL 与 `tables.toml` 生成 |
| `schema/queries/price_at.sql` | 按时点查价 |
| `schema/queries/unit_value_at.sql` | 计费单位换算（积分、平台货币、中转站额度 → 法币） |
| `schema/10_price_views.sql` | 查价视图：`price_current`（当前单价）、`price_history`（全部版本） |
| `docs/model/er-model.md` | 实体、时间语义、不变量与查价规则 |
| `docs/model/er-model.svg` | ER 图，由 `scripts/render_er.py` 从 DDL 生成 |
| `data/reference/` `data/models/` `data/clients/` | 参与方与字典、模型元信息、消费端客户端与其标签 |
| `data/channels/<渠道>/` | 各渠道的供给、价目卡、规则、套餐与缺口 |
| `data/sources/` | 来源登记：URL、抓取时间、sha256 |
| `scripts/build_catalog.py` | 由 `schema/` 与 `data/` 构建 SQLite 目录库并校验不变量 |
| `scripts/query_price.py` | 按时点查价的命令行，封装 `price_at.sql` |
| `tests/` | 用场景数据验收模型 |

## 使用

只依赖 Python 3.12 标准库与其自带的 SQLite（3.37 及以上）。

构建目录库（写入 `build/catalog.sqlite`，任一约束或不变量失败即非零退出）：

```bash
python3 scripts/build_catalog.py
```

运行验收测试：

```bash
python3 -m unittest discover -s tests
```

改了 `schema/01`–`04` 或 `schema/tables.toml` 后重新生成只增不改触发器（测试会校验是否同步）：

```bash
python3 scripts/gen_append_only.py
```

重新生成 ER 图（需要 Graphviz）：

```bash
python3 scripts/render_er.py
```

## 查价

**直接下载**：[Releases](https://github.com/meomeo-dev/llm-pricing-catalog/releases) 提供预构建的
`catalog.sqlite` 与 `prices.csv`（`price_history` 视图导出），不需要 Python。

**命令行**：先运行 `python3 scripts/build_catalog.py` 构建目录库，再查询：

```bash
python3 scripts/query_price.py claude-opus-5-5
python3 scripts/query_price.py claude-opus-5-5 --channel aws-bedrock --region geo
python3 scripts/query_price.py gpt-5 --tier batch --at 2026-06-01 --json
```

模型可以写规范 ID 或别名；不指定渠道时查厂商自己的 API；`--at` 查历史时点。查不到时
列出该模型当前的（渠道, 服务档, 地域, 计价单位）组合。`--help` 列出全部参数。

**SQL**：`price_current` 是当前生效的单价，`price_history` 是全部历史版本；每行是一个计价项
的单价，按 `per_quantity` 个 `quantity_unit` 计（token 类计价项为每百万 token），并附来源 URL。

```bash
sqlite3 -header -column build/catalog.sqlite "
  SELECT channel_id, region_id, meter_id, amount, price_unit_id
    FROM price_current
   WHERE model_id = 'claude-opus-5-5' AND service_tier = 'standard'
   ORDER BY channel_id, region_id, meter_id"
```

某一时刻的价格：

```sql
SELECT meter_id, amount, source_url
  FROM price_history
 WHERE model_id = 'claude-opus-5-5' AND channel_id = 'anthropic-api'
   AND service_tier = 'standard' AND region_id = 'global'
   AND valid_from <= '2026-10-01T00:00:00Z'
   AND (valid_to IS NULL OR '2026-10-01T00:00:00Z' < valid_to);
```

需要别名解析、客户端参考渠道、长上下文阶梯或回放某时刻的已知数据时，用
`schema/queries/price_at.sql`（命名参数见文件；`scripts/query_price.py` 是它的封装）。

## 数据来源

每张价目卡通过 `source_id` 指向 `data/sources/` 中的来源记录，记录包含页面 URL、
抓取时间与抓取内容的 sha256。价格以厂商官方页面为准；本目录可能滞后于页面变更。

数据只包含结构化字段；`excerpt`、`notes`、`usage_limit_text` 等自由文本列在本仓库数据中
为空。

## 许可证

| 范围 | 许可证 |
|---|---|
| 代码：`schema/`、`scripts/`、`tests/` | MIT，见 [LICENSE](LICENSE) |
| 数据与文档：`data/`、`docs/` | CC0-1.0，见 [LICENSE-DATA](LICENSE-DATA) |

产品名称与商标归各自所有者。
