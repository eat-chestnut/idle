# Phase-one Godot Client

## 当前定位

当前客户端正式定位已经调整为：

- 单机为主，弱联网为辅
- 启动时只做一次后台检查
- 进入游戏后，运行期主循环逐步以本地 runtime state 为真相
- 当前弱联网边界只保留存档上传 / 下载

当前目录正式承接的主链是：

- 启动检查
- 角色
- 主线
- 出战
- Battle
- Settle
- 背包
- 穿戴
- 角色成长回流

当前目录不负责：

- 新增 backend 接口
- 把客户端继续做成“实时 API 真相客户端”
- 排行榜、交易所、多人协同、复杂在线状态系统
- 强化、洗练、宝石、套装、经卷、world level、商店、活动等未来系统

## 当前联网边界

### 启动时
客户端当前只允许集中做一次启动检查，用于确认：

- 游戏 / 应用版本
- 配置 / 数据版本
- 资源版本（若当前后端或项目已声明）
- 存档上传 / 下载服务是否可用

启动检查结果必须写入本地 runtime state，供后续页面只读展示或提示使用。

### 进入游戏后
当前正式方向是：

- 页面主循环不再以实时 API 为真相
- 页面优先读本地 runtime state
- 旧接口可以暂时保留，作为迁移阶段的数据补齐手段
- 不能把“还没完全切完”当成继续强化在线客户端结构的理由

### 当前保留的弱联网能力

- 存档上传
- 存档下载

排行榜、交易所等未来能力后续再单独扩，不在本轮范围内。

## 契约与参考来源

客户端当前需要同时遵守两类来源：

1. 本地运行时与弱联网边界文档
2. 现有 backend / OpenAPI / 接口文档

推荐参考顺序：

1. `doc/codex/单机运行时与弱联网边界.md`
2. `doc/codex/游戏端开发总纲.md`
3. `doc/codex/游戏端页面与入口清单.md`
4. `doc/codex/游戏端状态与交互清单.md`
5. 当前真实 client 代码
6. `backend/routes/api.php`、`backend/docs/api/phase-one-frontend.openapi.json`

说明：

- backend 契约仍然约束当前已存在的启动检查兼容层与存档能力
- 但运行期页面组织，不应再默认以后端实时返回为唯一真相

## 关键入口

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- 后端访问封装：`client/scripts/backend_api.gd`
- 本地配置：`client/scripts/client_config_store.gd`
- merge gate：`client/phase-one-merge-gate.sh`
- online smoke：`client/scripts/phase_one_online_smoke.gd`

## 本地开发建议

以下命令默认从仓库根目录执行。

如果需要本地 backend：

```bash
cd ./backend
php artisan serve
```

GUI 自测建议顺序：

1. 打开 `project.godot`
2. 运行 `client/scenes/PhaseOneClient.tscn`
3. 在启动页确认 `Backend Base URL` 与 `Bearer Token`
4. 执行一次启动检查
5. 进入角色 / 主线 / 出战 / Battle / Settle / 背包 / 穿戴 / 角色链路
6. 重点确认页面是否优先承接本地 runtime state，而不是反复要求实时接口

## Merge Gate 与 Smoke

统一入口：

```bash
./client/phase-one-merge-gate.sh
```

说明：

- merge gate 与 online smoke 仍是当前仓库的开发保障手段
- 它们只证明现有主链、现有契约和现有联调环境可运行
- 它们不代表未来正式运行模式，更不代表“运行期应持续依赖实时 API”

## 当前限制与边界

- 当前目录只覆盖单机刷图成长主链与最小弱联网边界
- 启动检查当前会优先复用现有 `/readyz` 能力；若后端尚未显式提供版本或存档字段，客户端会以兼容快照形式记录 `unknown` 或 `not_declared`
- 页面必须继续显式处理 `loading / success / empty / error / unauthorized`
- 旧 API 链路本轮不会一次性删除，但后续新增页面逻辑必须优先落在本地 runtime state 上
