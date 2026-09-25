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
| `docs/model/er-model.md` | 实体、时间语义、不变量与查价规则 |
| `docs/model/er-model.svg` | ER 图，由 `scripts/render_er.py` 从 DDL 生成 |
| `data/reference/` `data/models/` `data/clients/` | 参与方与字典、模型元信息、消费端客户端与其标签 |
| `data/channels/<渠道>/` | 各渠道的供给、价目卡、规则、套餐与缺口 |
| `data/sources/` | 来源登记：URL、抓取时间、sha256 |
| `scripts/build_catalog.py` | 由 `schema/` 与 `data/` 构建 SQLite 目录库并校验不变量 |
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
