# ui-state-guard

## 目的

用于约束《山海巡厄录》项目游戏端页面状态完整性，避免“只会展示成功态”的半成实现。

## 适用场景

当任务涉及：
- 页面开发
- 列表页
- 详情页
- 战斗准备/结算展示
- 奖励状态展示
- 错误处理
时启用。

## 核心规则

每个页面必须先明确以下状态：

1. loading
2. success
3. empty
4. error
5. unauthorized

如果页面涉及业务状态，还必须补充：

6. locked / unlocked
7. reward available / claimed
8. submitting / retrying
9. no data / partial data

## 强制要求

- 不允许白屏代替 empty
- 不允许静默失败
- 不允许 token 过期后继续停留在失效状态无反馈
- 不允许把“未知状态”伪装成“成功状态”

## 战斗相关页面

### battle prepare
至少处理：
- preparing
- success
- error
- unauthorized

### battle settle
至少处理：
- settling
- success
- error
- unauthorized

## 奖励相关页面

至少处理：
- 有奖励
- 无奖励
- 未领取
- 已领取
- grant_status 异常/失败（若有）

## Review 拦截点

- 接口失败后界面不更新
- 空列表白屏
- unauthorized 没有重登或回退逻辑
- reward 状态与后端不一致
