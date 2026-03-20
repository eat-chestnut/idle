# client-flow

## 目的

用于约束《山海巡厄录》项目游戏端开发时的页面顺序、接口接入顺序、状态处理顺序，避免客户端开发跑偏。

## 适用场景

当任务涉及以下任一内容时启用：
- 游戏端开发
- 页面开发
- 客户端 API 接入
- 客户端联调
- 客户端验收

## 核心规则

1. 优先做单条可玩的竖切
2. 页面必须按正式主链顺序推进
3. 不先铺很多半成页面
4. 不复制后端业务逻辑
5. 所有页面必须处理：
   - loading
   - success
   - empty
   - error
   - unauthorized
6. 首先打通这些页面：
   - 角色创建
   - 角色详情
   - 背包
   - 穿戴
   - 章节
   - 难度
   - battle prepare
   - battle settle
7. 先接真接口，再做额外包装
8. token / environment / readiness 前提必须先解决

## 推荐工作顺序

1. 接环境与 token
2. 角色创建
3. 角色详情
4. 背包
5. 穿戴
6. 章节
7. 难度
8. battle prepare
9. battle settle
10. reward state 展示

## 常见拦截点

- 本地 mock 成功但没接后端
- 只有 success 态，没有 error 态
- battle_context 客户端自行伪造
- reward 是否已领取由客户端猜测
