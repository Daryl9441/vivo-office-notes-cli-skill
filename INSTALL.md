# vivo 原子笔记 CLI + Codex Skill 安装包

这个 ZIP 包含 vivo 办公套件 6.8.2 随 App 分发的 Notes CLI 能力、一个可供 Codex 日常操作的 Skill，以及 macOS 安装脚本。CLI 通过 `127.0.0.1` 与办公套件通信，不直接修改 `NoteSync.db`。

## 快速安装（macOS）

1. 从 <https://liangzi.vivo.com/> 安装或升级 vivo 办公套件至 6.8.2 或更新版本，登录并完成笔记同步。
2. 解压本 ZIP，在解压后的目录运行：

   ```bash
   bash install.sh
   ```

3. 在办公套件打开“设置 → 功能设置 → 笔记 → 其他 → CLI”，开启开关并创建身份令牌。
4. 按用途选择权限：仅查询选“只读”；需要创建、追加或整理选“读写”。
5. 在终端配置令牌并验证：

   ```bash
   notes config --token='<从办公套件复制的 Token>'
   notes health
   notes version
   notes list --limit=3
   ```

安装目标：

- `~/.local/bin/notes`
- `~/.codex/skills/office-suite-notes`
- Token 配置：`~/.notes-cli.conf`（不会包含在 ZIP 中，权限 `600`）

## 本包包含什么

```text
INSTALL.md
install.sh
skill/office-suite-notes/
├── SKILL.md
├── agents/openai.yaml
├── references/
│   ├── commands.md
│   ├── provenance.md
│   └── setup.md
└── scripts/
    ├── notes
    └── notes.ps1
```

macOS 的 `notes` 基于官方脚本做了 Bash 3.2 兼容与凭据配置安全修补，具体见 `skill/office-suite-notes/references/provenance.md`。完整命令见 `skill/office-suite-notes/references/commands.md`。

## Windows

ZIP 中保留了官方 `notes.ps1`。Windows 用户应先安装最新版 vivo 办公套件，然后按 Skill 中的 PowerShell 调用方式使用；本包的 `install.sh` 仅适用于 macOS/Linux，Windows 脚本未在本机验证。
