# 命令参考

除 `health`、`cli:check` 和 `config` 外，命令都需要有效身份令牌。需要程序解析时统一加 `--json`。

| 命令 | 作用 |
|---|---|
| `notes health` | 检查本地服务与端口 |
| `notes version` | 查看办公套件版本和 Notes API 版本 |
| `notes cli:check` | 比较已安装 Skill 与 App 内置 Skill 的版本 |
| `notes config [--token=<token>] [--port=<port>]` | 查看配置状态，或保存 Token/端口 |
| `notes list [--folder=<id>] [--limit=20] [--page=1] [--json]` | 分页列出笔记摘要 |
| `notes read <id> [--json]` | 读取一条笔记及正文 |
| `notes search --query="..." [--limit=10] [--folder=<id>] [--json]` | 搜索标题和正文 |
| `notes create --title="..." (--content="..."\|--content-b64="...") [--folder=<id>] [--json]` | 创建笔记 |
| `notes update <id> [--title="..."] [--content="..."] [--content-b64="..."] [--folder=<id>] [--json]` | 改标题、追加正文或移动笔记 |
| `notes folders [--parent=<id>] [--json]` | 列出根文件夹或某文件夹的直接子文件夹 |
| `notes folder <id> [--json]` | 查看文件夹详情 |
| `notes folder:create --name="..." [--parent=<id>] [--json]` | 创建文件夹 |
| `notes folder:update <id> [--name="..."] [--parent=<id>] [--json]` | 重命名或移动文件夹 |
| `notes folder:notes <id> [--limit=20] [--page=1] [--json]` | 分页列出文件夹中的笔记 |

## JSON 结构

成功响应通常为：

```json
{"status":"success","data":{},"meta":{}}
```

先检查 `status`，再读取 `data`；分页结果从 `meta.total`、`meta.page`、`meta.page_size` 取得。

## 正文编码

简单 HTML 可直接传 `--content=`。中文、Markdown、多行文本和特殊字符优先使用 Base64：

```bash
encoded_content=$(base64 -i /absolute/path/to/note.md)
notes create --title="标题" --content-b64="$encoded_content" --json
```

Base64 只是命令行安全传参，不是加密。不要把编码后的私人正文写进日志或公开仓库。

## 已知边界

- `update` 只追加正文，不提供全文替换。
- 不支持删除笔记/文件夹、恢复回收站、复制附件、双向同步或操作加锁笔记。
- 搜索排序为：标题前缀匹配、标题包含、正文包含。
- 已删除笔记不会出现在结果中。
- 单次列表 `limit` 的服务端上限为 100。
