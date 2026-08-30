# 安装与配置

## 环境要求

- vivo 办公套件 macOS 版 6.8.2 或更新版本，并已登录、同步原子笔记。
- macOS 自带 `curl`，以及可用的 `python3`。
- `~/.local/bin` 在 `PATH` 中；本安装包的 `install.sh` 会把命令安装到这里。

官方客户端下载页：<https://liangzi.vivo.com/>

## 安装本 ZIP

解压后，在包目录执行：

```bash
bash install.sh
```

它会安装：

- CLI：`~/.local/bin/notes`
- Codex Skill：`~/.codex/skills/office-suite-notes`

## 开启 CLI 与获取 Token

在 vivo 办公套件中打开：

`设置 → 功能设置 → 笔记 → 其他 → CLI`

开启 CLI 后，创建身份令牌：

- 只需查询和总结时选“只读”。
- 需要创建、追加或整理笔记时选“读写”。
- 有效期尽量选择满足用途的最短期限。

复制 Token 后，在本机终端执行：

```bash
notes config --token='<token>'
```

Token 只保存在 `~/.notes-cli.conf`，文件权限应为 `600`。不要把 Token 放进 Skill、ZIP、聊天记录、脚本源码或版本库。

## 验证

```bash
notes health
notes version
notes cli:check
notes list --limit=3
```

错误处理：

- `Cannot connect`：启动 vivo 办公套件，并确认 CLI 开关已开启。
- `401 Unauthorized`：Token 无效或过期，重新创建后执行 `notes config --token=...`。
- `403 Forbidden`：当前为只读 Token，却执行了写命令。
- 端口不是 9200：在办公套件 CLI 页面确认端口，再执行 `notes config --port=<9200-9700>`。

## 升级

运行 `notes cli:check`。如果 App 内置 Skill 更新，把整个目录复制到当前 Skill（包括脚本），再重新应用本包 `references/provenance.md` 中记录的 macOS 兼容性修补，或使用包含新版修补的安装包。
