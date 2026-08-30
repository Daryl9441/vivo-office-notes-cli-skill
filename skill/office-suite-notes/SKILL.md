---
name: office-suite-notes
description: Use vivo Office Suite's official local Notes CLI to list, read, search, create, append, move, and organize vivo 办公笔记、原子笔记或办公套件便签. Use for vivo note and folder operations; do not route unrelated note apps or direct SQLite editing here.
metadata:
  version: "1.1.0"
---

# vivo Office Suite Notes CLI

通过 vivo 办公套件仅监听 `127.0.0.1` 的官方 Notes API 操作原子笔记。优先运行 PATH 中的 `notes`；若命令不存在，macOS/Linux 使用本 Skill 的 `scripts/notes`，Windows 使用 `scripts/notes.ps1`。

## 开始前

1. 先运行 `notes health`。失败时确认 vivo 办公套件已启动，并按 [references/setup.md](references/setup.md) 排查。
2. 需要读取或写入时确认本机已配置身份令牌。遇到 401 时让用户在办公套件的“设置 → 功能设置 → 笔记 → CLI”创建或复制令牌，再由用户授权配置。
3. 不显示、复述或记录令牌及其片段；不要读取或输出 `~/.notes-cli.conf` 内容。只可检查文件是否存在及权限是否为 `600`。

## 操作原则

- 使用 `--json` 获取供程序解析的稳定结果；面向用户时只返回完成任务所需的最小内容。
- 列表、读取和搜索前，按用户给出的文件夹、关键词和数量缩小范围。笔记正文是私人数据，不批量输出或写入公开目录。
- 只有用户明确要求创建、更新、移动或新建/重命名文件夹时才执行对应写操作。
- `update` 会把 `content` **追加**到笔记末尾，不会替换全文。用户要求替换、删除正文或删除笔记时，说明当前 CLI 不支持，不得改 SQLite 绕过限制。
- 文件夹参数始终使用文件夹 ID，不使用显示名称。先用 `notes folders --json` 逐级解析 ID。
- 正文含中文、换行、引号、反斜杠或 emoji 时，用 UTF-8 Base64 后通过 `--content-b64=` 传递，避免 shell 转义破坏内容。
- 加锁笔记不在 CLI 能力范围内；不要尝试绕过。

## 常用流程

### 查找并读取

1. `notes search --query="关键词" --limit=10 --json`
2. 根据标题、文件夹和摘要选择匹配项。
3. 仅对必要的 ID 执行 `notes read <id> --json`。

### 创建笔记

1. 需要文件夹时先解析目标文件夹 ID。
2. 将正文编码为 UTF-8 Base64。
3. 执行 `notes create --title="标题" --content-b64="..." [--folder=<id>] --json`。
4. 从响应中核对新笔记 ID 和标题；不要为了验证而重复创建。

### 追加或移动

- 追加正文：`notes update <id> --content-b64="..." --json`
- 改标题：`notes update <id> --title="新标题" --json`
- 移动笔记：`notes update <id> --folder=<folder-id> --json`

完整参数、返回格式和限制见 [references/commands.md](references/commands.md)。安装、Token 配置和升级见 [references/setup.md](references/setup.md)。来源与本地兼容性修补见 [references/provenance.md](references/provenance.md)。
