# Phase-one Godot Client

## 这条分支解决了什么

`codex/phase-one-client-round2` 的目标不是继续扩功能，而是把第一阶段客户端主路径收口到可以联调、可以 review、可以交接、可以进入最终合并检查准备的状态。

当前已经围绕真实 backend 打通并收口的内容包括：

- 角色列表、角色创建、角色详情、角色激活
- 背包读取、穿戴槽读取、穿戴与卸下
- 章节、关卡、难度、首通奖励状态读取
- `battle prepare -> battle settle` 的真实主链承接
- headless boot smoke、main scene smoke、online smoke、merge gate
- 客户端交接文档、review 清单、合并前检查清单

这条分支不负责：

- 再补新的 backend 接口
- 在 client 里复制掉落、奖励、battle context 业务真相
- 提前实现强化、洗练、宝石、套装、经卷、world level、商店、活动等未来系统

## 当前 backend / client 真实基线

当前 client 必须以后端真实实现为准，契约来源按优先级使用：

1. `backend/routes/api.php`、`ApiRequest`、`Resource`、Feature Tests
2. `backend/docs/api/phase-one-frontend.openapi.json`
3. `backend/docs/api/README.md`
4. `doc/codex/接口示例文档.md` 与 `doc/codex/认证与接口公共规则.md`

与本客户端强相关的真实接口基线是：

- `GET /readyz?profile=interop`
- `GET /api/characters`
- `POST /api/characters`
- `GET /api/characters/{character_id}`
- `POST /api/characters/{character_id}/activate`
- `GET /api/inventory`
- `GET /api/characters/{character_id}/equipment-slots`
- `POST /api/characters/{character_id}/equip`
- `POST /api/characters/{character_id}/unequip`
- `GET /api/chapters`
- `GET /api/chapters/{chapter_id}/stages`
- `GET /api/stages/{stage_id}/difficulties`
- `GET /api/stage-difficulties/{stage_difficulty_id}/first-clear-reward-status`
- `POST /api/battles/prepare`
- `POST /api/battles/settle`

当前客户端真实入口和关键文件：

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- API 封装：`client/scripts/backend_api.gd`
- merge gate：`client/phase-one-merge-gate.sh`
- 在线 smoke：`client/scripts/phase_one_online_smoke.gd`
- 合并前检查：`client/合并前检查清单.md`

## 当前如何联调

以下命令默认从仓库根目录执行。

联调前建议确认：

```bash
php ./backend/artisan phase-one:diagnose --profile=interop --json
php ./backend/artisan phase-one:contract-drift-check --json
```

本地最小联调默认值：

- `BACKEND_URL=http://127.0.0.1:8000`
- `BEARER_TOKEN=test-token-2001`
- 对应用户：`users.id = 2001`

如果 backend 尚未启动，可以手动运行：

```bash
cd ./backend
php artisan serve
```

也可以直接运行 merge gate，让脚本按需临时启动本地 backend。

### GUI 联调顺序

1. 打开根目录 Godot 工程 `project.godot`。
2. 运行主场景 `client/scenes/PhaseOneClient.tscn`。
3. 在“环境与 Token”页确认 `Backend Base URL` 与 `Bearer Token`。
4. 先跑 `/readyz?profile=interop`，确认环境可联调。
5. 读取角色列表；如列表为空，再创建角色。
6. 激活本次联调要使用的角色。
7. 读取背包与穿戴槽，确认当前角色上下文已同步。
8. 进入主线页，按“章节 -> 关卡 -> 难度”顺序选择目标。
9. 刷新首通奖励状态。
10. 先跑 `battle prepare`，再跑 `battle settle`，确认结算结果与奖励状态同步展示。

### 当前联调策略

- 客户端不伪造 `battle_context_id`，必须承接 prepare 返回值。
- 客户端不猜测奖励状态，必须以后端返回的 `first_clear_reward_status` 为准。
- 在线 smoke 只选第一个章节、第一个关卡、第一个难度，目标是最小正式闭环，不是全量覆盖。
- 角色为空时，smoke 只通过正式 `POST /api/characters` 补一个最小合法角色，不创建任何本地假数据。

## 当前如何运行 merge gate

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

merge gate 固定执行以下步骤：

1. `php ./backend/artisan phase-one:diagnose --profile=interop --json`
2. `php ./backend/artisan phase-one:contract-drift-check --json`
3. `godot --headless --path . --quit`
4. `godot --headless --path . --scene res://client/scenes/PhaseOneClient.tscn --quit-after 1`
5. `godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- --base-url=... --bearer-token=...`
6. `composer --working-dir=./backend phase-one:acceptance`

运行说明：

- 如果 `BACKEND_URL` 已在线，merge gate 会直接复用现有 backend。
- 如果 `BACKEND_URL` 不在线，merge gate 会临时启动 `php artisan serve`。
- 临时启动的日志会写到 `backend/storage/logs/client-merge-gate-server.log`。
- merge gate 不替代单独的 `acceptance` 诊断复核，也不替代 GUI 人工联调。

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

成功后脚本会打印摘要，至少包含：

- `character_id`
- `chapter_id`
- `stage_id`
- `stage_difficulty_id`
- `battle_context_id`
- `monster_count`
- `drop_count`
- `reward_count`
- `reward_status_before`
- `reward_status_after`

## 提交态 raw 如何复核

不要只看 IDE 视觉，也不要只看 `wc -l`。建议直接检查提交态原文片段：

```bash
git show HEAD:client/phase-one-merge-gate.sh | sed -n '1,40p'
git show HEAD:client/scripts/phase_one_online_smoke.gd | sed -n '1,60p'
git show HEAD:client/README.md | sed -n '1,80p'
git show HEAD:'client/合并前检查清单.md' | sed -n '1,120p'
```

如果提交态片段重新呈现压缩态、单行态或函数边界不清晰，应直接视为新的合并阻塞项。

## 当前限制与已知边界

- 当前 backend 最小客户端友好接口已经补齐；本分支不再新增接口。
- merge gate 与 online smoke 只能证明 headless 主链可跑，不能替代 GUI 页面级联调。
- online smoke 依赖 phase-one seed 数据与 `test-token-2001`。
- 如果账号已经领过首通奖励，smoke 可能读到“已领取状态回读”，这不等于奖励链有问题。
- 当前客户端仍以单条正式竖切为主，不追求多章节、多角色、多异常分支的全量覆盖。
- 页面必须继续显式处理 `loading / success / empty / error / unauthorized`，战斗页额外处理 `preparing / settling`。

## 最终合并前推荐执行顺序

建议从仓库根目录按以下顺序执行，并把结果回写到 `client/合并前检查清单.md`：

1. `./client/phase-one-merge-gate.sh`
2. `php ./backend/artisan phase-one:diagnose --profile=acceptance --json`
3. `php ./backend/artisan phase-one:contract-drift-check --json`
4. `composer --working-dir=./backend phase-one:acceptance`
5. `godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- --base-url=http://127.0.0.1:8000 --bearer-token=test-token-2001`
6. `git show HEAD:client/phase-one-merge-gate.sh | sed -n '1,40p'`
7. `git show HEAD:client/scripts/phase_one_online_smoke.gd | sed -n '1,60p'`
8. 如本轮改到了运行逻辑，再补一次非 headless GUI 联调
9. 执行 `git commit` 与 `git push`

最终是否可进入“合并回 `main` 前最终检查”，以 [client/合并前检查清单.md](./合并前检查清单.md) 的本轮复核结论为准。
