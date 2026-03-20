# Phase-one Godot Client

## 当前定位

这是根目录 Godot 工程下的 phase-one 正式主流程客户端。

当前目标不是继续补“最小缺失接口”。
而是把已经接上真实 backend 的客户端流程收口成一条更接近正式玩家路径的竖切：

1. 环境与 Token
2. 角色列表 / 角色创建
3. 角色详情与激活
4. 背包 / 穿戴
5. 章节 -> 关卡 -> 难度
6. battle prepare
7. battle settle

客户端继续以后端真实接口为业务真相，不本地 mock 正式成功态，也不复制后端业务规则。

## 合并前固定入口

当前 client 分支合并前统一先执行：

```bash
./client/phase-one-merge-gate.sh
```

默认使用：

- `BACKEND_URL=http://127.0.0.1:8000`
- `BEARER_TOKEN=test-token-2001`

如需覆盖，可临时传入：

```bash
BACKEND_URL=http://127.0.0.1:8010 BEARER_TOKEN=your-token ./client/phase-one-merge-gate.sh
```

该 gate 固定串起：

1. backend `phase-one:diagnose --profile=interop --json`
2. backend `phase-one:contract-drift-check --json`
3. Godot 项目启动 smoke
4. `PhaseOneClient.tscn` headless smoke
5. 基于 `client/scripts/backend_api.gd` 的真实 backend 在线 smoke
6. backend `composer phase-one:acceptance`

注意：

- 第 5 步属于“在线等价 smoke”，会真实走角色列表/激活/章节/关卡/难度/prepare/settle。
- 它不是完整 GUI 人工联调，不能替代窗口内点击验证。
- 完整合并判断仍以 [合并前检查清单](./合并前检查清单.md) 为准。

## 当前结构

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- API 封装：`client/scripts/backend_api.gd`
- 配置存储：`client/scripts/client_config_store.gd`
- 分页脚本：
  - `client/scripts/pages/phase_one_config_page.gd`
  - `client/scripts/pages/phase_one_character_page.gd`
  - `client/scripts/pages/phase_one_inventory_page.gd`
  - `client/scripts/pages/phase_one_equipment_page.gd`
  - `client/scripts/pages/phase_one_stage_page.gd`
  - `client/scripts/pages/phase_one_prepare_page.gd`
  - `client/scripts/pages/phase_one_settle_page.gd`

## 当前真实口径

- `GET /api/characters` 已作为角色选择主入口。
- `POST /api/characters/{character_id}/activate` 已作为 battle 主路径的正式角色切换入口。
- 主线路径真相：
  `GET /api/chapters` -> `GET /api/chapters/{chapter_id}/stages` -> `GET /api/stages/{stage_id}/difficulties`
- 选择难度后，客户端会刷新首通奖励状态，并把结果同步到 prepare / settle。
- prepare 成功后，客户端会自动承接：
  - `battle_context_id`
  - `character_id`
  - `stage_difficulty_id`
  - `killed_monsters`
- 结算页默认承接 prepare 结果；手输覆盖只保留在“联调覆盖输入”里。

当前角色激活口径以真实 backend 为准：

- 首个角色默认会成为当前启用角色
- 后续新建角色默认 `is_active=0`
- battle prepare / settle 仍优先使用当前启用角色

## 当前主流程

### 1. 环境与 Token

- 先确认 `Backend Base URL`
- 再确认 `Bearer Token`
- 先跑 `/readyz?profile=interop`
- 再用章节接口探测保护接口是否可联调

### 2. 角色

- 先读取真实角色列表
- 若列表为空，再创建角色
- 需要进入 battle 主流程时，优先把目标角色设为当前出战角色
- 角色详情页会把当前角色同步到背包、穿戴和 battle 上下文

### 3. 背包与穿戴

- 背包页真实读取 `GET /api/inventory`
- 装备实例可以直接带到穿戴页
- 穿戴页只提交：
  - `equipment_instance_id`
  - `target_slot_key`

### 4. 主线

- 先读取章节
- 选择章节后自动读取该章节关卡
- 选择关卡后自动读取难度列表
- 选择难度后自动刷新首通奖励状态，并把难度同步到 prepare / settle

### 5. 战斗

- prepare 页优先使用当前启用角色 + 当前已选难度
- prepare 成功后自动切到 settle 页
- settle 页默认承接本轮 prepare 结果，可直接提交结算
- 如需联调异常路径，可展开“联调覆盖输入”手工覆盖：
  - `character_id`
  - `stage_difficulty_id`
  - `battle_context_id`
  - `killed_monsters`

## 页面状态

所有页面继续保证以下基础状态：

- `loading`
- `success`
- `empty`
- `error`
- `unauthorized`

战斗相关页面额外保证：

- `preparing`
- `settling`
- prepare -> settle 自动承接
- 首通奖励状态以后端返回为准

## 运行方式

以下命令默认都从仓库根目录执行。

1. 启动 backend，并确保 phase-one 联调前提已满足。
2. 打开根目录 Godot 工程：
   - `project.godot`
3. 运行主场景：
   - `client/scenes/PhaseOneClient.tscn`
4. 在“环境与 Token”页确认：
   - `Backend Base URL`
   - `Bearer Token`
5. 先跑 `/readyz` 预检，再按正式主流程推进。

默认联调值：

- `http://127.0.0.1:8000`
- `test-token-2001`

## 最小联调前置

backend 启动前建议先执行：

```bash
cd backend
php artisan phase-one:diagnose --profile=interop --json
php artisan phase-one:contract-drift-check --json
```

如果需要最小联调账号：

- Bearer Token：`test-token-2001`
- 对应用户：`users.id = 2001`

## 验证分层

### 自动化守门

```bash
./client/phase-one-merge-gate.sh
```

### 真实 backend 在线等价 smoke

脚本内部会执行：

```bash
godot --headless --path . \
  --script ./client/scripts/phase_one_online_smoke.gd -- \
  --base-url=http://127.0.0.1:8000 \
  --bearer-token=test-token-2001
```

覆盖目标：

- `/readyz?profile=interop`
- `GET /api/characters`
- `POST /api/characters/{character_id}/activate`
- `GET /api/chapters`
- `GET /api/chapters/{chapter_id}/stages`
- `GET /api/stages/{stage_id}/difficulties`
- `GET /api/stage-difficulties/{stage_difficulty_id}/first-clear-reward-status`
- `POST /api/battles/prepare`
- `POST /api/battles/settle`

### GUI 人工最小回归

1. 环境页 `/readyz` 成功，章节接口探测成功。
2. 角色页读取真实角色列表；如为空，创建角色。
3. 选择一个角色并确认 battle 主路径使用当前启用角色。
4. 主线页完成章节 -> 关卡 -> 难度选择，确认首通奖励状态刷新。
5. prepare 成功后自动切到 settle 页，且 `battle_context_id`、怪物列表已承接。
6. settle 成功后能看到掉落、奖励、入包与首通奖励状态，并可回到背包/穿戴继续查看。

## 合并前检查

合并前请再过一遍：

- [合并前检查清单](./合并前检查清单.md)

## 文档入口

- 合并判断与验证记录：[client/合并前检查清单.md](./合并前检查清单.md)
- backend 联调入口：[backend/docs/api/README.md](../backend/docs/api/README.md)
- OpenAPI 契约：[backend/docs/api/phase-one-frontend.openapi.json](../backend/docs/api/phase-one-frontend.openapi.json)
- 人读接口示例：[doc/codex/接口示例文档.md](../doc/codex/接口示例文档.md)
