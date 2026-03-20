---
name: architecture-guard
description: 在 idle 项目中开发任何后端业务功能前，先应用本技能。用于约束五层架构、职责分层、目录落点与代码边界，防止把业务逻辑写进 Controller / Model / 路由。
---

# 目标
你正在为 `idle` 项目开发代码。该项目当前以第一阶段主链交付为目标，强调：

- 五层结构清晰
- 业务链闭环
- 配置层 / 实例层分离
- 掉落链 / 奖励链分离
- Controller 轻薄
- Workflow 编排、Domain 计算、Query 读取

你的首要任务不是“尽快写代码”，而是“确保代码落点正确、职责不串层、不破坏主链”。

# 必须遵守的架构规则

## 1. Controller 只做入口，不做业务
Controller 只能负责：
- 参数接收
- 调用 Workflow / Query Service
- 返回 Resource / JSON
- 基础异常转换

Controller 禁止：
- 写业务规则
- 直接操作多个模型完成主流程
- 写战斗、掉落、奖励、背包、属性重算等核心逻辑
- 写事务主流程

## 2. Workflow 负责编排，不写底层查询拼装
Workflow 用于串联一个完整业务链，例如：
- 创建角色
- 换装
- 战斗准备
- 战斗结算
- 奖励发放
- 入包

Workflow 应承担：
- 开启事务
- 组织多个 Domain / Query Service
- 做主链顺序控制
- 做幂等防重入口控制
- 返回统一结果 DTO / 数组

## 3. Domain 负责业务规则与纯计算
Domain Service 应承担：
- 战斗计算
- 属性聚合与重算
- 掉落解析
- 奖励明细构造
- 背包写入拆分规则
- 装备槽位合法性判断

## 4. Query 只读，不写状态
Query Service 只做：
- 查询
- 聚合读取
- 后台列表读取
- 详情展示读取
- 战斗准备所需只读快照查询

Query Service 禁止：
- 更新数据
- 触发奖励
- 写入背包
- 修改角色状态

## 5. Model 只作为数据映射层
Eloquent Model 不承载复杂业务。

允许：
- relation
- casts
- 基础 scope
- 轻量 accessor

禁止：
- 在 Model 中塞主业务流程
- 在 Model 事件中偷偷发奖励、写背包、改属性
- 在 Observer 中做关键主链

# 目录落点规则
新功能必须优先落到现有业务域内，例如：
- `app/Services/Battle/...`
- `app/Services/Character/...`
- `app/Services/Drop/...`
- `app/Services/Equipment/...`
- `app/Services/Inventory/...`
- `app/Services/Reward/...`
- `app/Services/Stage/...`
- `app/Services/Admin/...`

不要随意新建顶层 `Helpers`、`Managers`、`Utils`、`Engines` 来逃避分层。

# 实施步骤
在开始任何实现前，必须先做这 4 步：
1. 先判断该需求属于哪个业务域
2. 再判断它是 Workflow / Domain / Query 哪一层
3. 明确输入输出与事务边界
4. 再开始改代码

# 输出代码时的要求
你每次提交方案时，优先给出：
1. 修改文件清单
2. 每个文件职责
3. 为什么落在这一层
4. 再给代码

# 自检清单
- 是否把业务逻辑写进 Controller 了？
- 是否把写操作塞进 Query 了？
- 是否跳过 Workflow 直接从入口拼业务链了？
- 是否把纯规则和 IO/事务混在一起了？
- 是否引入了新的混乱目录？
- 是否可以由现有业务域承载，而不是新增大而全服务？

任一答案为“是”，先重构再交付。
