# 来源与本地修补

## 官方来源

本包以 vivo 办公套件 6.8.2（macOS）内置资源为基础：

```text
/Applications/pcsuite.app/Contents/Resources/skills/office-suite-notes/
```

本机检查到的上游文件版本与 SHA-256：

```text
SKILL.md   version 1.1.0
           8cb36225ce3ff2f8e6b336fc564e27f2adda7c20b06f25ec8b0f362ddafb5744
notes      CLI 1.0.0
           917cce4a4744284a7dfe6977167477f6adcf10ba5ce724a68935d224e2057e9c
notes.ps1  fb42e587e58fbee9dae544c2190d2cb3c5aa8033fa0fa559eae785dfa3034b34
```

App 的签名元数据显示身份为 `Developer ID Application: vivo Mobile Communication Co., Ltd. (NR23K45T29)`；本机完整 Gatekeeper 校验同时报告了 bundle 资源缺失，因此这里仅把签名身份作为来源线索，不把它表述为完整性校验通过。公开官网暂未提供单独 CLI 文档；CLI 说明与脚本随桌面 App 分发。

网络搜索还发现了社区项目 <https://github.com/gobylor/vivo-note-cli>。它是读取 `NoteSync.db` 的第三方只读导出器，不是办公套件内置的本地 HTTP CLI，也不支持本 Skill 所需的创建、追加和文件夹管理，因此本包没有安装或依赖它。

## macOS 修补

上游 `notes` 在 macOS 系统 Bash 3.2 中开启 `set -u` 后展开空数组，会在未配置 Token 时触发 `auth_header[@]: unbound variable`，使 `notes health` 误报连接失败。本包做了以下最小修补：

1. 有/无 Token 时分别调用 `curl`，不再展开空数组。
2. 不再 `source ~/.notes-cli.conf`，改为只解析 `NOTES_TOKEN` 与 `NOTES_PORT`，避免配置文件被当作 shell 代码执行。
3. 配置按整行匹配键名，只移除第一个 `=` 前缀，完整保留 Base64 Token 末尾的 `=` 填充。
4. `notes config` 保留未修改的配置项、校验端口、强制权限 `600`。
5. 非 JSON 错误响应不会再被 `set -e` 静默吞掉，认证失败会显示明确错误。
6. 配置状态只显示“configured/not configured”，不输出 Token 片段。

Windows 的 `notes.ps1` 保持 6.8.2 内置原版，已随 Skill 附带，但未在本机执行验证。
