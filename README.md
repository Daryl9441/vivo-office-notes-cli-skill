# vivo Office Notes CLI Skill

面向 Codex 的 vivo 办公笔记 / 原子笔记日常操作 Skill。它通过 vivo 办公套件仅监听本机 `127.0.0.1` 的 Notes API，支持查询、读取、搜索、创建、追加、移动笔记以及文件夹管理。

本仓库是社区整理的安装包，不是 vivo 官方发布仓库。CLI 来源、macOS 兼容修补及校验信息见 [`skill/office-suite-notes/references/provenance.md`](skill/office-suite-notes/references/provenance.md)。

## 安装

环境要求：

- vivo 办公套件 macOS 版 6.8.2 或更新版本
- `curl` 和 `python3`
- Codex（使用 Skill 时）

克隆仓库后执行：

```bash
bash install.sh
```

随后在 vivo 办公套件中打开：

`设置 → 功能设置 → 笔记 → 其他 → CLI`

创建令牌并在本机配置：

```bash
notes config --token='<从办公套件复制的 Token>'
notes health
notes version
```

完整安装说明见 [`INSTALL.md`](INSTALL.md)，命令参考见 [`skill/office-suite-notes/references/commands.md`](skill/office-suite-notes/references/commands.md)。

## 隐私与安全

- 仓库不包含身份令牌、笔记数据库、笔记标题、笔记正文或用户目录信息。
- Token 只保存在本机 `~/.notes-cli.conf`，安装脚本不会把它复制进 Skill。
- Notes 服务只通过 `127.0.0.1` 访问；不要把端口转发到公网。
- 提交或公开仓库前运行 `bash scripts/audit_privacy.sh`。
- 如果 Token 曾出现在聊天、日志或提交历史中，请立即在 vivo 办公套件中撤销并重新创建。

## 已知限制

- 当前 CLI 不支持删除笔记或文件夹，也不支持全文替换。
- `update` 对正文执行追加，不是覆盖。
- 加锁笔记、附件复制、回收站恢复和双向同步不在能力范围内。
- Windows 脚本随包保留，但尚未在本项目中完成实机验证。

## 公开发布前

请先阅读 [`NOTICE.md`](NOTICE.md)。仓库包含从 vivo 办公套件内置资源整理、修改的文件；公开分发前应自行确认相关授权和商标使用要求。
