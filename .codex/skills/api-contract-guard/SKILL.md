# api-contract-guard

## 目的

用于约束《山海巡厄录》项目在客户端接入与 backend 持续迭代过程中，避免 API 契约漂移。

## 适用场景

当任务涉及以下任一内容时启用：
- Request / Resource 变更
- OpenAPI 更新
- 根目录接口示例文档更新
- 游戏端接口接入
- CI 中的 contract drift check
- 接口验收

## 核心规则

1. 真实代码优先于旧文档
2. 不允许维护三套互相冲突的真相
3. 必须明确：
   - backend 真实代码
   - backend OpenAPI
   - 根目录 `doc/codex/接口示例文档.md`
   的主次关系
4. 当接口变更时，至少检查：
   - routes
   - Request
   - Resource
   - OpenAPI
   - 根目录正式文档
   - 相关测试
5. 不允许已删除接口继续留在正式文档中
6. 不允许客户端继续依赖已移除字段
7. 统一响应结构必须继续保持：
   - code
   - message
   - data
8. Bearer Token 口径不得漂移

## 推荐检查项

- 是否新增/删除正式接口
- 是否修改了请求字段
- 是否修改了响应字段
- 是否修改了错误码语义
- 是否修改了枚举值
- OpenAPI 是否同步
- 根目录正式文档是否同步
- 客户端接入清单是否同步
