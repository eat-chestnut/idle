# Phase-one Godot Client

## 当前定位

这是根目录 Godot 工程下的第一阶段正式客户端竖切。
当前分支的重点不是继续补 backend 接口，也不是扩未来系统，而是把已经接上真实 backend 的客户端主流程收口到可联调、可复核、可合并前检查的状态。

客户端继续以后端真实实现为业务真相：

- 不本地 mock 正式成功态
- 不复制后端掉落 / 奖励 / battle_context 规则
- 不用客户端默认值替代真实角色、真实关卡、真实奖励状态

## 这条分支解决了什么

相对 `main`，`codex/phase-one-client-round2` 已经把以下客户端主链收口到真实 backend：

- 角色列表、角色创建、角色详情、角色激活
- 背包与穿戴页的真实接口接入
- 章节 -> 关卡 -> 难度的真实选择链路
- 首通奖励状态刷新与 prepare / settle 承接
- `battle prepare -> battle settle` 的主路径状态传递
- 客户端 merge gate、headless main-scene smoke、真实 backend 在线 smoke
- 客户端交接文档、review 清单与合并前检查清单

本轮“最后工程质量收口”只继续做以下事情：

- 收口 `client/phase-one-merge-gate.sh` 的可读性、注释和执行入口
- 收口 `client/scripts/phase_one_online_smoke.gd` 的可读性和分段结构
- 补全本 README 与合并前检查清单，方便团队交接和最终合并检查

## 关键文件

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- API 封装：`client/scripts/backend_api.gd`
- 配置存储：`client/scripts/client_config_store.gd`
- merge gate：`client/phase-one-merge-gate.sh`
- 在线 smoke：`client/scripts/phase_one_online_smoke.gd`
- 合并前检查清单：`client/合并前检查清单.md`

页面脚本当前按 phase-one 主链拆分为：

- `client/scripts/pages/phase_one_config_page.gd`
- `client/scripts/pages/phase_one_character_page.gd`
- `client/scripts/pages/phase_one_inventory_page.gd`
- `client/scripts/pages/phase_one_equipment_page.gd`
- `client/scripts/pages/phase_one_stage_page.gd`
- `client/scripts/pages/phase_one_prepare_page.gd`
- `client/scripts/pages/phase_one_settle_page.gd`

## 最小联调前置

以下命令默认都从仓库根目录执行。

需要的本地命令：

- `godot`
- `php`
- `composer`
- `curl`

建议先确认 backend 最小联调前提：

```bash
php ./backend/artisan phase-one:diagnose --profile=interop --json
php ./backend/artisan phase-one:contract-drift-check --json
```

如果 backend 还没启动，可手动执行：

```bash
cd ./backend
php artisan serve
```

也可以直接运行 merge gate，让脚本按需临时拉起本地 backend。

当前最小联调账号：

- `BACKEND_URL=http://127.0.0.1:8000`
- `BEARER_TOKEN=test-token-2001`
- 对应用户：`users.id = 2001`

## 当前如何联调

### 1. 打开客户端

1. 打开根目录 Godot 工程 `project.godot`
2. 运行主场景 `client/scenes/PhaseOneClient.tscn`
3. 先在“环境与 Token”页确认：
   - `Backend Base URL`
   - `Bearer Token`
4. 先执行 `/readyz?profile=interop` 预检，再进入正式主链

### 2. 角色与出战角色

角色页当前以真实接口为准：

- `GET /api/characters`
- `POST /api/characters`
- `GET /api/characters/{character_id}`
- `POST /api/characters/{character_id}/activate`

联调顺序建议：

1. 先拉角色列表
2. 若列表为空，再创建角色
3. 进入战斗主链前，显式激活目标角色
4. 角色详情会把当前角色同步给背包、穿戴和 battle 页面

### 3. 背包、穿戴与主线

当前页面主链：

- 背包：`GET /api/inventory`
- 穿戴：`GET /api/characters/{character_id}/equipment-slots`
- 穿戴提交：`POST /api/characters/{character_id}/equip`
- 卸下提交：`POST /api/characters/{character_id}/unequip`
- 主线：`GET /api/chapters`
- 关卡：`GET /api/chapters/{chapter_id}/stages`
- 难度：`GET /api/stages/{stage_id}/difficulties`
- 首通奖励状态：`GET /api/stage-difficulties/{stage_difficulty_id}/first-clear-reward-status`

联调顺序建议：

1. 先读章节
2. 再读章节下关卡
3. 再读关卡难度
4. 选择难度后刷新首通奖励状态
5. 再进入 prepare / settle

### 4. 战斗主链

当前 phase-one battle 路径：

- `POST /api/battles/prepare`
- `POST /api/battles/settle`

当前真实口径：

- prepare 必须使用真实 `character_id` 与真实 `stage_difficulty_id`
- settle 必须承接 prepare 返回的 `battle_context_id`
- 客户端不自己伪造 `battle_context_id`
- prepare 成功后，客户端会自动承接：
  - `battle_context_id`
  - `character_id`
  - `stage_difficulty_id`
  - `killed_monsters`

如需联调异常路径，settle 页仍保留“联调覆盖输入”，但它只用于调试覆盖，不替代主路径承接。

## 当前如何跑 merge gate

统一入口：

```bash
./client/phase-one-merge-gate.sh
```

查看帮助：

```bash
./client/phase-one-merge-gate.sh --help
```

如需覆盖默认环境：

```bash
BACKEND_URL=http://127.0.0.1:8010 \
BEARER_TOKEN=your-token \
./client/phase-one-merge-gate.sh
```

可选环境变量：

- `BACKEND_URL`
- `BEARER_TOKEN`
- `MERGE_GATE_HOST`
- `MERGE_GATE_PORT`
- `GODOT_BIN`
- `PHP_BIN`
- `COMPOSER_BIN`

merge gate 固定执行以下步骤：

1. `php ./backend/artisan phase-one:diagnose --profile=interop --json`
2. `php ./backend/artisan phase-one:contract-drift-check --json`
3. `godot --headless --path . --quit`
4. `godot --headless --path . --scene res://client/scenes/PhaseOneClient.tscn --quit-after 1`
5. `godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- --base-url=... --bearer-token=...`
6. `composer --working-dir=./backend phase-one:acceptance`

执行说明：

- 如果 `BACKEND_URL` 已在线，merge gate 会直接复用现有 backend
- 如果 `BACKEND_URL` 不在线，merge gate 会临时启动 `php ./backend/artisan serve`
- 临时启动的 backend 日志会写到 `backend/storage/logs/client-merge-gate-server.log`
- 第 5 步是“真实 backend 在线 + 客户端 API 层”的等价 smoke，不等于 GUI 窗口逐页联调

## 在线 smoke 覆盖内容

`client/scripts/phase_one_online_smoke.gd` 当前固定覆盖：

1. `GET /readyz?profile=interop`
2. `GET /api/characters`
3. 必要时 `POST /api/characters`
4. `POST /api/characters/{character_id}/activate`
5. `GET /api/chapters`
6. `GET /api/chapters/{chapter_id}/stages`
7. `GET /api/stages/{stage_id}/difficulties`
8. `GET /api/stage-difficulties/{stage_difficulty_id}/first-clear-reward-status`
9. `POST /api/battles/prepare`
10. `POST /api/battles/settle`

脚本策略：

- 优先复用当前激活角色
- 无角色时通过正式创建接口补一个最小 smoke 角色
- 优先选第一个章节、第一个关卡、第一个难度做最小闭环
- 成功后打印本次在线 smoke 摘要，方便回写到检查清单

## 页面状态要求

所有页面都必须继续显式处理：

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

## 当前限制

当前分支的目标是支撑最终合并检查，但是否真正进入该阶段，仍以后续 merge gate、在线 smoke、GUI 记录和合并前检查清单为准。
在此之前，需要明确以下限制：

- 本轮不再补新 backend 接口；若联调发现接口问题，应回到 backend 契约收口，不在 client 里猜测补偿
- merge gate 和在线 smoke 只能证明 headless 主链可跑，不能替代 GUI 窗口逐页联调
- 在线 smoke 依赖 phase-one seed 数据与 `test-token-2001`
- 在线 smoke 选择“第一个章节 / 第一个关卡 / 第一个难度”，它验证的是最小正式闭环，不是所有分支覆盖
- 如果本地账号已经领过首通奖励，在线 smoke 可能验证到“已领取状态回读”，而不是“首次发奖状态变化”
- “未领取 -> 已领取”的首通奖励过渡仍以 backend acceptance / smoke tests 为最终真相
- 当前 phase-one 仍不包含强化、洗练、宝石、套装、经卷、world level、商店、活动等未来系统

## 合并前看哪里

最终是否可进入“合并回 `main` 前最终检查”，以以下文件为准：

- [client/合并前检查清单.md](./合并前检查清单.md)
- [backend/docs/api/README.md](../backend/docs/api/README.md)
- [backend/docs/api/phase-one-frontend.openapi.json](../backend/docs/api/phase-one-frontend.openapi.json)
- [doc/codex/接口示例文档.md](../doc/codex/接口示例文档.md)
- [doc/codex/第一阶段测试与验收说明.md](../doc/codex/第一阶段测试与验收说明.md)
