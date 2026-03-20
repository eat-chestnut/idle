# Phase-one Godot Client

## 目标

这是根目录 Godot 工程下的 phase-one 第二轮客户端接入。

本轮仍然只做真实 backend 联调，不做本地 mock 成功页；但会把上一轮“单脚本最小竖切”整理成更顺手的联调客户端：

1. 页面拆分为独立分页脚本
2. 角色 / stage / difficulty 选择流程收口
3. battle prepare / settle 上下文自动承接
4. 补 `/readyz` 联调预检入口

## 当前结构

- 主场景：`res://client/scenes/PhaseOneClient.tscn`
- 主协调器：`res://client/scripts/phase_one_client.gd`
- API 封装：`res://client/scripts/backend_api.gd`
- 配置存储：`res://client/scripts/client_config_store.gd`
- 分页脚本：
  - `res://client/scripts/pages/phase_one_config_page.gd`
  - `res://client/scripts/pages/phase_one_character_page.gd`
  - `res://client/scripts/pages/phase_one_inventory_page.gd`
  - `res://client/scripts/pages/phase_one_equipment_page.gd`
  - `res://client/scripts/pages/phase_one_stage_page.gd`
  - `res://client/scripts/pages/phase_one_prepare_page.gd`
  - `res://client/scripts/pages/phase_one_settle_page.gd`

## 当前真实约束

- 当前没有正式 `GET /api/characters` 角色列表接口。
- 当前没有正式 stage list API，`GET /api/chapters` 也不返回 `stage_id`。
- 新建角色当前默认 `is_active=0`。
- battle prepare / settle 仍要求使用可战斗角色。

因此本客户端的“角色选择器”和“stage 选择器”都不是伪造的正式列表，而是：

- 最近成功创建/读取过的真实角色记录
- 最近成功请求过的 `stage_id / stage_difficulty_id`
- 当前文档和 seed 默认联调值

## 运行方式

1. 启动 backend，并确保 phase-one 联调前提可用。
2. 打开仓库根目录 Godot 工程：
   - `/Users/mumu/game/idle/project.godot`
3. 运行主场景：
   - `res://client/scenes/PhaseOneClient.tscn`
4. 在“环境与 Token”页填写或使用默认值：
   - `Backend Base URL`
   - `Bearer Token`
5. 先点击：
   - `联调预检 /readyz`
6. 再按主链逐步联调。

默认联调值：

- `http://127.0.0.1:8000`
- `test-token-2001`
- `character_id = 1001`
- `stage_id = stage_nanshan_001`
- `stage_difficulty_id = stage_nanshan_001_normal`

## 推荐联调顺序

1. 环境与 Token
   - 先跑 `/readyz` 预检
   - 再用“探测章节接口”验证保护接口 + token
2. 角色
   - 创建角色或读取已有角色
   - 观察当前角色是否 `is_active=1`
3. 背包
   - 读取背包
   - 直接从装备实例列表跳到穿戴页
4. 穿戴
   - 读取槽位
   - 选择槽位并 equip / unequip
5. 章节与难度
   - 读取章节
   - 用最近成功 `stage_id` 或默认联调 `stage_id` 读取难度
   - 选择难度并刷新首通奖励状态
6. Battle Prepare
   - 选择可战斗角色
   - 直接承接已选难度执行 prepare
7. Battle Settle
   - 自动承接 `battle_context_id`
   - 可一键填入 prepare 阶段的 monster 列表

## 页面状态

每个页面继续保证：

- loading
- success
- empty
- error
- unauthorized

战斗页额外保证：

- preparing / settling
- battle_context 自动承接
- reward status 以后端返回为准

## 本地最小验证

脚本和场景的本地 smoke check：

```bash
godot --headless --path /Users/mumu/game/idle --quit
godot --headless --path /Users/mumu/game/idle res://client/scenes/PhaseOneClient.tscn --quit-after 1
```

backend 联调前建议先确认：

```bash
cd /Users/mumu/game/idle/backend
php artisan phase-one:diagnose --profile=interop --json
curl http://127.0.0.1:8000/readyz
```

## 本轮体验改进点

- 页面不再全部堆在一个脚本里，主脚本只负责编排与跨页同步。
- 角色页、穿戴页、battle 页都支持“最近真实角色”选择，减少手输 `character_id`。
- 章节页明确区分“真实章节接口结果”和“最近成功 stage_id”，不伪造 stage list。
- prepare 成功后会自动同步：
  - `battle_context_id`
  - `stage_difficulty_id`
  - `killed_monsters`
- 配置页新增 `/readyz` 联调预检入口。
