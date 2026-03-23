# Phase-one Godot Client

## 正式运行模式

当前客户端的正式方向是：

- 单机为主，弱联网为辅
- 启动时联网一次
- 进入游戏后，主循环逐步以本地 `runtime state` 为真相
- 当前运行期弱联网只保留存档上传 / 下载

当前正式主链是：

`启动检查 -> 角色 -> 主线 -> 出战 -> Battle -> Settle -> 背包 -> 穿戴 -> 角色成长回流`

当前目录不负责：

- 新增 backend 接口
- 把客户端继续做成“实时 API 真相客户端”
- 排行榜、交易所、多人协同、复杂在线状态系统
- 强化、洗练、宝石、套装、经卷、world level、商店、活动等未来系统

## 运行时真相边界

### 启动阶段

客户端正常启动时，只允许集中做一次启动检查，用于确认：

- 游戏 / 应用版本
- 配置 / 数据版本
- 资源版本（若当前项目或后端已声明）
- 存档上传 / 下载服务是否可用

这次检查的结果必须写入本地 `runtime state`。

### 进入游戏后

进入游戏后，当前主循环的设计原则是：

- 页面优先读本地 `runtime state`
- 角色、主线、背包、穿戴、Battle、Settle、成长承接逐步本地化
- 旧接口可以暂时保留，但只作为迁移阶段的数据补齐手段
- 不能继续把“页面切换就请求一次接口”当成正式运行模型

### 当前弱联网边界

当前运行期只保留：

- 存档上传
- 存档下载

它们是本地真相的附属同步能力，不是页面主循环驱动器。

## 参考顺序

客户端当前推荐按以下顺序对齐：

1. `doc/codex/单机运行时与弱联网边界.md`
2. `doc/codex/游戏端开发总纲.md`
3. `doc/codex/游戏端页面与入口清单.md`
4. `doc/codex/游戏端状态与交互清单.md`
5. 当前真实 client 代码
6. 现有 backend / OpenAPI 契约（仅用于启动检查兼容与迁移阶段旧接口）

说明：

- backend 仍约束当前启动检查兼容层与旧接口兼容链
- 但运行期页面组织，不应再默认以后端实时返回为唯一真相

## 关键入口

- Godot 工程入口：`project.godot`
- 主场景：`client/scenes/PhaseOneClient.tscn`
- 主协调器：`client/scripts/phase_one_client.gd`
- 本地运行时：`client/scripts/local_game_state.gd`
- 弱联网访问封装：`client/scripts/backend_api.gd`
- 本地配置：`client/scripts/client_config_store.gd`

## 启动页定位

启动页当前的正式身份是“启动检查入口”。

它负责：

- 生成启动快照
- 展示版本 / 资源 / 存档服务状态
- 承接弱联网地址与旧接口兼容令牌

它不再是：

- 联调首页
- 产品主循环真相来源
- “先把一堆 API 探一遍” 的准备页

## 本地开发与最小自测

以下命令默认从仓库根目录执行。

如果需要本地 backend 作为启动检查兼容源或旧接口兼容源：

```bash
cd ./backend
php artisan serve
```

GUI 自测建议顺序：

1. 打开 `project.godot`
2. 运行 `client/scenes/PhaseOneClient.tscn`
3. 在“启动检查”页确认启动检查地址；如需走旧接口兼容链，再补令牌
4. 执行一次启动检查
5. 进入角色 / 主线 / 出战 / Battle / Settle / 背包 / 穿戴 / 角色链路
6. 重点确认页面是否优先承接本地 `runtime state`

## 开发验证工具

统一入口：

```bash
./client/phase-one-merge-gate.sh
```

当前仓库仍保留：

- `client/phase-one-merge-gate.sh`
- `client/scripts/phase_one_online_smoke.gd`

它们的定位只能是：

- 开发期契约验证工具
- 后端能力 smoke 工具
- 回归检查工具

它们不代表：

- 正式运行模式
- 页面主循环真相来源
- 未来客户端应持续依赖实时接口

## 当前限制与边界

- 当前目录只覆盖单机刷图成长主链与最小弱联网边界
- 启动检查当前优先复用现有 `/readyz`；若后端未显式提供版本或存档字段，客户端会以兼容快照记录 `unknown` 或 `not_declared`
- 页面必须继续显式处理 `loading / success / empty / error / unauthorized`
- 旧 API 链路本轮不会一次性删除，但后续新增页面逻辑必须优先落在本地 `runtime state` 上
