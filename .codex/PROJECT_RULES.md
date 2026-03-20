# Project Rules

这是 `CODEX.md` 的补充版，给需要读取 `.codex/` 目录的代理使用。

核心原则：

1. 先对齐 `doc` 与当前真实代码，再写代码。
2. 先保证第一阶段已存在主链的正确性、可追溯性、可补发性，再考虑扩展。
3. 优先复用现有 Workflow / Domain / Query，不随意重写。
4. 能做最小增量闭环，就不要回退架构或扩成完整新系统。
5. 每轮任务都应输出 git 状态、验证步骤与提交结果。

推荐默认加载：
- `skills/architecture-guard`
- `skills/dev-flow`
- `skills/scope-guard`

以下按需加载：
- `skills/battle-flow`
- `skills/db-rules`
