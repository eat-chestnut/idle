---
name: battle-flow
description: 当需求涉及战斗准备、战斗结算、掉落、奖励、属性快照或 battle context 时使用。用于确保战斗主链严格按 idle 项目的既定业务顺序与当前仓库已收口的事务语义实现。
---

# 目标
本技能用于保护战斗主链，不允许出现“能跑但链路脏”的实现。

# 主链原则
战斗主链必须遵守如下顺序：
1. 准备阶段：读取角色、装备、属性、关卡配置
2. 生成 battle context / 快照 / 状态
3. 执行战斗计算
4. 解析普通掉落
5. 普通掉落统一入包
6. 判定首通奖励
7. 走正式奖励发放链
8. 收口结算结果与上下文状态

关键原则：
- 掉落链与奖励链必须分离
- 普通掉落不能绕开 Inventory 正式入包
- 首通奖励不能伪装成普通掉落
- 战斗结算不允许直接手写发放到背包各表

# 当前仓库特别规则
当前仓库已经收口为：
- battle context 持久化
- battle settle 正式回查 context
- reward failed 记录可沉淀
- 后台补发可承接 failed 记录

因此：
- 不要把当前语义回退成“大事务全回滚、失败记录完全不留”的旧模型
- 如果调整事务边界，必须先说明现状与目标差异
- 必须保证 success / failed / retry 语义仍可追溯

# 代码落点约束
战斗结算必须由 Battle Workflow 发起，并调用协作域服务：
- `BattleSettlementWorkflow`
- `Drop` 域负责掉落解析
- `Inventory` 域负责正式入包
- `RewardGrantWorkflow` 负责首通等正式奖励发放

不允许在 Controller 直接：
- 解析掉落
- 发放奖励
- 写入背包
- 改 battle context 状态

# battle context 规则
如果需求涉及 battle context：
- 必须明确状态流转
- 必须明确结算前后可重复调用规则
- 必须考虑幂等与重复提交
- 必须区分“已准备未结算”和“已结算”
- 必须绑定 user / character / stage_difficulty

# 典型反例（禁止）
- 在 `BattleController` 里直接 `DB::transaction(...)`
- 在结算逻辑里直接插入 `inventory_stack_items`
- 把首通奖励直接混进普通掉落数组
- 跳过 RewardGrantWorkflow 直接插 `user_reward_grants`
- 跳过 InventoryWriteService 直接插装备实例表
- 为了“简单”去掉 failed reward_grant 沉淀能力

# 自检清单
- 是否存在 `prepare` 与 `settle` 主链分工？
- 是否所有正式掉落都走统一入包？
- 是否首通奖励走奖励发放链？
- 是否考虑 battle context 的重复提交？
- 是否尊重当前仓库已实现的 failed grant 沉淀与补发承接？
- 是否把战斗逻辑错误地下沉到 Controller / Model？
- 是否有清晰的结果输出结构给 API / Resource？
