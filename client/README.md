# Phase-one Godot Client

## 当前范围

本目录提供《山海巡厄录》第一阶段 Godot 客户端最小可玩竖切，当前正式覆盖：

- 环境与 Bearer Token 配置
- 角色列表、角色创建、角色详情、角色激活
- 背包读取、穿戴槽读取、装备穿戴与卸下
- 章节、关卡、难度、首通奖励状态读取
- `battle prepare -> battle settle` 的真实链路承接
- headless boot smoke、main-scene smoke、online smoke、merge gate

当前目录不负责：

- 新增 backend 接口
- 在 client 里复制掉落、奖励、battle context 的业务真相
- 强化、洗练、宝石、套装、经卷、world level、商店、活动等未来系统

## 契约来源

当前 client 的正式契约来源按以下顺序使用：

1. `backend/routes/api.php`、各 `ApiRequest`、各 `Resource`、相关 Feature Tests
2. `backend/docs/api/phase-one-frontend.openapi.json`
3. `backend/docs/api/README.md`
4. `doc/codex/接口示例文档.md`
5. `doc/codex/认证与接口公共规则.md`

当前强相关正式接口包括：

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

## 关键入口

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- API 封装：`client/scripts/backend_api.gd`
- merge gate：`client/phase-one-merge-gate.sh`
- online smoke：`client/scripts/phase_one_online_smoke.gd`

当前最小本地联调固定值：

- `BACKEND_URL=http://127.0.0.1:8000`
- `BEARER_TOKEN=test-token-2001`
- 对应测试用户：`users.id = 2001`

## 本地联调

以下命令默认从仓库根目录执行。

联调前建议先确认 backend 最小可联调状态：

```bash
php ./backend/artisan phase-one:diagnose --profile=interop --json
php ./backend/artisan phase-one:contract-drift-check --json
```

如果 backend 尚未启动，可以手动运行：

```bash
cd ./backend
php artisan serve
```

GUI 联调建议顺序：

1. 打开根目录 Godot 工程 `project.godot`
2. 运行主场景 `client/scenes/PhaseOneClient.tscn`
3. 在“环境与 Token”页确认 `Backend Base URL` 与 `Bearer Token`
4. 执行 `/readyz?profile=interop`
5. 读取角色列表；若列表为空，再创建角色
6. 激活联调角色
7. 读取背包与穿戴槽
8. 在主线页按“章节 -> 关卡 -> 难度”顺序选择目标
9. 刷新首通奖励状态
10. 先跑 `battle prepare`，再跑 `battle settle`

当前联调策略：

- 客户端不伪造 `battle_context_id`，必须承接 prepare 返回值
- 客户端不猜测奖励状态，必须以后端返回的 `first_clear_reward_status` 为准
- online smoke 固定只选第一个章节、第一个关卡、第一个难度，目标是最小正式闭环
- 角色为空时，smoke 只通过正式 `POST /api/characters` 创建最小合法角色

## Merge Gate 与 Smoke

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

merge gate 固定执行以下顺序：

1. `php ./backend/artisan phase-one:diagnose --profile=interop --json`
2. `php ./backend/artisan phase-one:contract-drift-check --json`
3. `godot --headless --path . --quit`
4. `godot --headless --path . --scene res://client/scenes/PhaseOneClient.tscn --quit-after 1`
5. `godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- --base-url=... --bearer-token=...`
6. `composer --working-dir=./backend phase-one:acceptance`

`client/scripts/phase_one_online_smoke.gd` 固定覆盖：

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

运行说明：

- 如果 `BACKEND_URL` 已在线，merge gate 会直接复用现有 backend
- 如果 `BACKEND_URL` 不在线，merge gate 会临时启动 `php artisan serve`
- 临时服务日志会写到 `backend/storage/logs/client-merge-gate-server.log`
- merge gate 不替代单独的 acceptance diagnose，也不替代 GUI 联调

## 验证建议

建议从仓库根目录按以下顺序验证：

1. `./client/phase-one-merge-gate.sh`
2. `php ./backend/artisan phase-one:diagnose --profile=acceptance --json`
3. `php ./backend/artisan phase-one:contract-drift-check --json`
4. `composer --working-dir=./backend phase-one:acceptance`
5. 再补一次非 headless GUI 联调

## 当前限制与边界

- 当前目录只覆盖 phase-one 正式主链，不扩展未来系统
- merge gate 与 online smoke 只能证明 headless 主链可跑，不能替代 GUI 页面级联调
- online smoke 依赖 phase-one seed 数据与 `test-token-2001`
- 如果账号已经领过首通奖励，smoke 可能读到“已领取状态回读”，这不等于奖励链有问题
- 当前客户端仍以单条正式竖切为主，不追求多章节、多角色、多异常分支的全量覆盖
- 页面必须继续显式处理 `loading / success / empty / error / unauthorized`，战斗页额外处理 `preparing / settling`
