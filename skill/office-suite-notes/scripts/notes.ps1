#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$CLI_VERSION = "1.0.0"
$CONFIG_FILE = "$env:USERPROFILE\.notes-cli.conf"

if (Test-Path $CONFIG_FILE) {
    Get-Content $CONFIG_FILE | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            Set-Item "env:$($matches[1])" $matches[2]
        }
    }
}

$NOTES_PORT = if ($env:NOTES_PORT) { $env:NOTES_PORT } else { "9200" }
$NOTES_TOKEN = if ($env:NOTES_TOKEN) { $env:NOTES_TOKEN } else { "" }

$BASE_URL = "http://127.0.0.1:${NOTES_PORT}/third-party"
$HEALTH_URL = "http://127.0.0.1:${NOTES_PORT}/health"

# ---------- helpers ----------
#
# Encoding notes (Windows PowerShell 5.1):
#
# 1) REQUEST body: when -Body is a [string], Invoke-WebRequest encodes it with
#    ISO-8859-1 / the system code page, so non-ASCII characters (e.g. Chinese
#    folder names) are sent as literal '?' (0x3F) and arrive garbled. Adding
#    "charset=utf-8" to the Content-Type header does NOT fix this. The reliable
#    fix — working on both PS 5.1 and PS 7 — is to pass the body as a UTF-8
#    byte[] AND declare the charset via the -ContentType parameter.
#    IMPORTANT: do NOT return the byte[] from a helper function. PowerShell
#    stream-collects a function's output, which turns a returned [byte[]] into
#    an [object[]]. Invoke-WebRequest then stringifies the Object[] to
#    "123 34 110 ..." (space-separated decimal), corrupting the body. Build the
#    byte[] inline at the call site and assign it with an explicit [byte[]]
#    cast so it stays Byte[].
#
# 2) RESPONSE body: when the server's Content-Type header has NO charset,
#    Invoke-WebRequest decodes .Content as ISO-8859-1 (Latin-1), not UTF-8.
#    UTF-8 bytes for e.g. "子" (E5 AD 90) then become "å­\x90" — the classic
#    "å­æä»¶" mojibake. Setting [Console]::OutputEncoding does NOT fix this:
#    the string is already corrupted before it reaches the console. The fix is
#    to read the raw bytes from RawContentStream and decode them as UTF-8
#    ourselves. (PS 7 defaults to UTF-8 already, so this is a harmless no-op
#    there.) We also set [Console]::OutputEncoding = UTF8 at the top of the
#    script so the correctly-decoded string is emitted to the terminal as
#    UTF-8 rather than the system code page.

function Get-ResponseBody {
    param($Response)
    # Decode the response body as UTF-8 regardless of the Content-Type charset.
    # .Content is already a Latin-1-mangled string on PS 5.1 when no charset is
    # declared, so read the raw bytes and decode them ourselves. RawContentStream
    # is a MemoryStream present on both PS 5.1 (Invoke-WebRequest response) and
    # PS 7 (BasicParseContext). Fall back to .Content if it's somehow missing.
    if ($Response.PSObject.Properties.Name -contains 'RawContentStream' -and $null -ne $Response.RawContentStream) {
        return [System.Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray())
    }
    return $Response.Content
}

function Decode-Base64 {
    param([string]$Encoded)
    try {
        $bytes = [System.Convert]::FromBase64String($Encoded)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        Write-Host "Error: invalid base64 in --content-b64: $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-GetRequest {
    param([string]$Url)
    $headers = @{}
    if ($NOTES_TOKEN) { $headers["Authorization"] = "Bearer $NOTES_TOKEN" }
    try {
        $response = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec 30 -UseBasicParsing
        @{ Body = (Get-ResponseBody $response); StatusCode = $response.StatusCode }
    } catch {
        @{ Body = $_.Exception.Message; StatusCode = 0 }
    }
}

function Invoke-PostRequest {
    param([string]$Url, [string]$Body)
    $headers = @{}
    if ($NOTES_TOKEN) { $headers["Authorization"] = "Bearer $NOTES_TOKEN" }
    [byte[]]$bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Post -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 30 -UseBasicParsing
        @{ Body = (Get-ResponseBody $response); StatusCode = $response.StatusCode }
    } catch {
        @{ Body = $_.Exception.Message; StatusCode = 0 }
    }
}

function Invoke-PutRequest {
    param([string]$Url, [string]$Body)
    $headers = @{}
    if ($NOTES_TOKEN) { $headers["Authorization"] = "Bearer $NOTES_TOKEN" }
    [byte[]]$bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Put -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bytes -TimeoutSec 30 -UseBasicParsing
        @{ Body = (Get-ResponseBody $response); StatusCode = $response.StatusCode }
    } catch {
        @{ Body = $_.Exception.Message; StatusCode = 0 }
    }
}

function Format-Error {
    param([hashtable]$Response)
    if ($Response.StatusCode -eq 401) {
        Write-Host "Error: Authentication failed (401 Unauthorized)"
        Write-Host "Please check if the Token is valid or expired. Reconfigure with:"
        Write-Host "  notes config --token=<new-token>"
        exit 1
    }
    try {
        $obj = $Response.Body | ConvertFrom-Json
        Write-Host "Error: $($obj.error.code) - $($obj.error.message)"
    } catch {
        Write-Host $Response.Body
    }
    exit 1
}

function Format-Success {
    param([string]$Body, [hashtable]$Response)
    try {
        $obj = $Body | ConvertFrom-Json
        return $obj
    } catch {
        Format-Error $Response
    }
}

# ---------- commands ----------

function cmd_health {
    $resp = Invoke-GetRequest $HEALTH_URL
    if ($resp.StatusCode -eq 0) {
        Write-Host "Error: Cannot connect to $BASE_URL"
        Write-Host "Please check if Office Suite is running."
        exit 1
    }
    $obj = Format-Success $resp.Body $resp
    $port = if ($obj.port) { $obj.port } else { "unknown" }
    Write-Host "Server is running at ${BASE_URL} (port ${port})"
}

function cmd_version {
    $resp = Invoke-GetRequest "$BASE_URL/version"
    if ($resp.StatusCode -eq 0) {
        Write-Host "Error: Cannot connect to $BASE_URL"
        Write-Host "Please check if Office Suite is running."
        exit 1
    }
    $obj = Format-Success $resp.Body $resp
    if ($obj.status -ne "success") { Format-Error $resp }
    $app_ver = if ($obj.data.appVersion) { $obj.data.appVersion } else { "unknown" }
    $api_ver = if ($obj.data.apiVersion) { $obj.data.apiVersion } else { "unknown" }
    Write-Host "${app_ver} (api: ${api_ver})"
}

function cmd_list {
    $folder = ""; $limit = "20"; $page = "1"; $json = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--folder=*" { $folder = $args[$i].Substring(9) }
            "--limit=*" { $limit = $args[$i].Substring(8) }
            "--page=*" { $page = $args[$i].Substring(7) }
            "--json" { $json = $true }
        }
    }

    $params = "limit=${limit}&page=${page}"
    if ($folder) { $params += "&folder=" + [uri]::EscapeDataString($folder) }

    $resp = Invoke-GetRequest "${BASE_URL}/notes?${params}"
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $data = $obj.data
    $meta = $obj.meta
    for ($i = 0; $i -lt $data.Count; $i++) {
        $n = $data[$i]
        Write-Host "$($i+1). [$($n.id)] $($n.title)  ($($n.folder))"
    }
    Write-Host "---"
    $total = if ($meta.PSObject.Properties.Name -contains "total") { $meta.total } else { $data.Count }
    Write-Host "Total: ${total} notes"
}

function cmd_read {
    if ($args.Count -eq 0) { Write-Host "Error: note id is required"; exit 1 }
    $id = $args[0]; $json = $false
    if ($args.Count -gt 1 -and $args[1] -eq "--json") { $json = $true }

    $resp = Invoke-GetRequest "${BASE_URL}/notes/${id}"
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $d = $obj.data
    Write-Host "ID: $($d.id)"
    Write-Host "Title: $($d.title)"
    Write-Host "Folder: $($d.folder)"
    if ($d.PSObject.Properties.Name -contains "created") { Write-Host "Created: $($d.created)" }
    if ($d.PSObject.Properties.Name -contains "updated") { Write-Host "Updated: $($d.updated)" }
    Write-Host "---"
    if ($d.PSObject.Properties.Name -contains "content") { Write-Host $d.content }
}

function cmd_create {
    $title = ""; $content = ""; $content_b64 = ""; $folder = ""; $json = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--title=*" { $title = $args[$i].Substring(8) }
            "--content=*" { $content = $args[$i].Substring(10) }
            "--content-b64=*" { $content_b64 = $args[$i].Substring(14) }
            "--folder=*" { $folder = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }
    if ($content_b64) { $content = Decode-Base64 $content_b64 }

    if (-not $title) { Write-Host "Error: --title is required"; exit 1 }

    $bodyObj = @{ title = $title }
    if ($content) { $bodyObj.content = $content }
    if ($folder) { $bodyObj.folder = $folder }
    $body = $bodyObj | ConvertTo-Json -Depth 3 -Compress

    $resp = Invoke-PostRequest "${BASE_URL}/notes" $body
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    Write-Host "Created: $($obj.data.id) - $($obj.data.title)"
}

function cmd_update {
    if ($args.Count -eq 0) { Write-Host "Error: note id is required"; exit 1 }
    $id = $args[0]
    $title = ""; $content = ""; $folder = ""; $json = $false
    for ($i = 1; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--title=*" { $title = $args[$i].Substring(8) }
            "--content=*" { $content = $args[$i].Substring(10) }
            "--content-b64=*" { $content_b64 = $args[$i].Substring(14) }
            "--folder=*" { $folder = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }
    if ($content_b64) { $content = Decode-Base64 $content_b64 }

    $bodyObj = @{}
    if ($title) { $bodyObj.title = $title }
    if ($content) { $bodyObj.content = $content }
    if ($folder) { $bodyObj.folder = $folder }
    $body = $bodyObj | ConvertTo-Json -Depth 3 -Compress

    $resp = Invoke-PutRequest "${BASE_URL}/notes/${id}" $body
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    Write-Host "Updated: $($obj.data.id) - $($obj.data.title)"
}

function cmd_search {
    $query = ""; $limit = "10"; $folder = ""; $json = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--query=*" { $query = $args[$i].Substring(8) }
            "--limit=*" { $limit = $args[$i].Substring(8) }
            "--folder=*" { $folder = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }

    if (-not $query) { Write-Host "Error: --query is required"; exit 1 }

    $params = "query=" + [uri]::EscapeDataString($query) + "&limit=${limit}"
    if ($folder) { $params += "&folder=" + [uri]::EscapeDataString($folder) }

    $resp = Invoke-GetRequest "${BASE_URL}/notes/search?${params}"
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $data = $obj.data
    $meta = $obj.meta
    Write-Host "Search: `"$($meta.query)`""
    Write-Host "---"
    for ($i = 0; $i -lt $data.Count; $i++) {
        $n = $data[$i]
        Write-Host "$($i+1). [$($n.id)] $($n.title)  ($($n.folder))"
        if ($n.PSObject.Properties.Name -contains "snippet" -and $n.snippet) {
            Write-Host "  $($n.snippet)"
        }
    }
    $total = if ($meta.PSObject.Properties.Name -contains "total") { $meta.total } else { $data.Count }
    Write-Host "Total: ${total} results"
}

function cmd_folders {
    $parent = ""; $json = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--parent=*" { $parent = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }

    $url = "${BASE_URL}/folders"
    if ($parent) { $url += "?parent=" + [uri]::EscapeDataString($parent) }

    $resp = Invoke-GetRequest $url
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $data = $obj.data
    for ($i = 0; $i -lt $data.Count; $i++) {
        $f = $data[$i]
        $parentStr = if (-not $f.parent_id) { "root" } else { "→ $($f.parent_id)" }
        $count = if ($f.PSObject.Properties.Name -contains "note_count") { $f.note_count } else { 0 }
        Write-Host "$($i+1). [$($f.id)] $($f.name)  ($($parentStr), ${count} notes)"
    }
    Write-Host "---"
    Write-Host "Total: $($data.Count) folders"
}

function cmd_folder {
    if ($args.Count -eq 0) { Write-Host "Error: folder id is required"; exit 1 }
    $id = $args[0]; $json = $false
    if ($args.Count -gt 1 -and $args[1] -eq "--json") { $json = $true }

    $resp = Invoke-GetRequest "${BASE_URL}/folders/${id}"
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $d = $obj.data
    $parentStr = if (-not $d.parent_id) { "root" } else { $d.parent_id }
    $count = if ($d.PSObject.Properties.Name -contains "note_count") { $d.note_count } else { 0 }
    Write-Host "ID: $($d.id)"
    Write-Host "Name: $($d.name)"
    Write-Host "Parent folder: $($parentStr)"
    Write-Host "Notes: ${count} (direct)"
}

function cmd_folder_create {
    $name = ""; $parent = ""; $json = $false
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--name=*" { $name = $args[$i].Substring(7) }
            "--parent=*" { $parent = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }

    if (-not $name) { Write-Host "Error: --name is required"; exit 1 }

    $bodyObj = @{ name = $name }
    if ($parent) { $bodyObj.parent_id = $parent }
    $body = $bodyObj | ConvertTo-Json -Depth 3 -Compress

    $resp = Invoke-PostRequest "${BASE_URL}/folders" $body
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $d = $obj.data
    $parentStr = if (-not $d.parent_id) { "root" } else { "→ $($d.parent_id)" }
    Write-Host "Created: $($d.id) - $($d.name) ($($parentStr))"
}

function cmd_folder_update {
    if ($args.Count -eq 0) { Write-Host "Error: folder id is required"; exit 1 }
    $id = $args[0]
    $name = ""; $parent = ""; $json = $false
    for ($i = 1; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--name=*" { $name = $args[$i].Substring(7) }
            "--parent=*" { $parent = $args[$i].Substring(9) }
            "--json" { $json = $true }
        }
    }

    $bodyObj = @{}
    if ($name) { $bodyObj.name = $name }
    if ($parent) { $bodyObj.parent_id = $parent }
    $body = $bodyObj | ConvertTo-Json -Depth 3 -Compress

    $resp = Invoke-PutRequest "${BASE_URL}/folders/${id}" $body
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $d = $obj.data
    $parentStr = if (-not $d.parent_id) { "root" } else { "→ $($d.parent_id)" }
    Write-Host "Updated: $($d.id) - $($d.name) ($($parentStr))"
}

function cmd_folder_notes {
    if ($args.Count -eq 0) { Write-Host "Error: folder id is required"; exit 1 }
    $id = $args[0]
    $limit = "20"; $page = "1"; $json = $false
    for ($i = 1; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--limit=*" { $limit = $args[$i].Substring(8) }
            "--page=*" { $page = $args[$i].Substring(7) }
            "--json" { $json = $true }
        }
    }

    $resp = Invoke-GetRequest "${BASE_URL}/folders/${id}/notes?limit=${limit}&page=${page}"
    $obj = Format-Success $resp.Body $resp

    if ($json) { Write-Host $resp.Body; return }

    if ($obj.status -ne "success") { Format-Error $resp }

    $data = $obj.data
    $meta = $obj.meta
    for ($i = 0; $i -lt $data.Count; $i++) {
        $n = $data[$i]
        Write-Host "$($i+1). [$($n.id)] $($n.title)  ($($n.folder))"
    }
    Write-Host "---"
    $total = if ($meta.PSObject.Properties.Name -contains "total") { $meta.total } else { $data.Count }
    $pg = if ($meta.PSObject.Properties.Name -contains "page") { $meta.page } else { 1 }
    $ps = if ($meta.PSObject.Properties.Name -contains "page_size") { $meta.page_size } else { $data.Count }
    $totalPages = [math]::Ceiling([int]$total / [int]$ps)
    Write-Host "Total: ${total} (page ${pg}/${totalPages})"
}

function cmd_cli_check {
    $resp = Invoke-GetRequest "$BASE_URL/cli/version"
    if ($resp.StatusCode -eq 0) {
        Write-Host "Error: Cannot connect to $BASE_URL"
        Write-Host "Please check if Office Suite is running."
        exit 1
    }
    $obj = Format-Success $resp.Body $resp
    if ($obj.status -ne "success") { Format-Error $resp }

    $cliSkillDir = $PSScriptRoot
    $localSkill = "unknown"
    $skillFile = Join-Path $cliSkillDir "SKILL.md"
    if (Test-Path $skillFile) {
        try {
            $content = Get-Content $skillFile -Raw -Encoding UTF8
            if ($content -match '(?m)^version:\s*["'']?([\w.\-]+)["'']?') {
                $localSkill = $Matches[1]
            }
        } catch { }
    }

    $remoteSkill = if ($obj.data.skill_version) { $obj.data.skill_version } else { "unknown" }
    $upgradePrompt = if ($obj.data.upgrade_prompt) { $obj.data.upgrade_prompt } else { "" }

    Write-Host "Current version:"
    Write-Host "  Skill: $localSkill"
    Write-Host "  Path:  $skillFile"
    Write-Host "Latest version:"
    Write-Host "  Skill: $remoteSkill"
    if ($upgradePrompt) {
        Write-Host "Upgrade prompt:"
        Write-Host $upgradePrompt
    }
    Write-Host "---"

    if ($localSkill -ne $remoteSkill) {
        Write-Host "Status: update available"
    } else {
        Write-Host "Status: up to date"
    }
}

function cmd_config {
    $token = ""; $port = ""; $showOnly = $true
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -Wildcard ($args[$i]) {
            "--token=*" { $token = $args[$i].Substring(8); $showOnly = $false }
            "--port=*" { $port = $args[$i].Substring(7); $showOnly = $false }
        }
    }

    if ($showOnly) {
        $tokenDisplay = if ($NOTES_TOKEN.Length -gt 20) { $NOTES_TOKEN.Substring(0, 16) + "..." + $NOTES_TOKEN.Substring($NOTES_TOKEN.Length - 4) } else { $NOTES_TOKEN }
        Write-Host "Current config:"
        Write-Host "  Token: ${tokenDisplay}"
        Write-Host "  Port:  ${NOTES_PORT}"
        Write-Host "  Config file: ${CONFIG_FILE}"
        return
    }

    $lines = @()
    if ($token) { $lines += "NOTES_TOKEN=${token}" }
    if ($port) { $lines += "NOTES_PORT=${port}" }
    $lines | Set-Content -Path $CONFIG_FILE -Encoding UTF8

    Write-Host "Config saved to ${CONFIG_FILE}"
    Write-Host "Current config:"
    if ($token) {
        $tokenDisplay = if ($token.Length -gt 20) { $token.Substring(0, 16) + "..." + $token.Substring($token.Length - 4) } else { $token }
        Write-Host "  Token: ${tokenDisplay}"
    }
    if ($port) { Write-Host "  Port:  ${port}" }
    Write-Host ""
    Write-Host "Subsequent commands will read this config automatically."
}

# ---------- main ----------

function Show-Usage {
    Write-Host "Notes CLI v${CLI_VERSION}"
    Write-Host ""
    Write-Host "Usage: notes <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  health                  Check server connectivity"
    Write-Host "  version                 Show App version"
    Write-Host "  list    [--folder=] [--limit=20] [--page=1] [--json]"
    Write-Host "  read    <id> [--json]"
    Write-Host "  create  --title= [--content=] [--content-b64=] [--folder=] [--json]"
    Write-Host "  update  <id> [--title=] [--content=] [--content-b64=] [--folder=] [--json]"
    Write-Host "  search  --query= [--limit=10] [--folder=] [--json]"
    Write-Host "  folders [--parent=] [--json]"
    Write-Host "  folder  <id> [--json]"
    Write-Host "  folder:create  --name= [--parent=] [--json]"
    Write-Host "  folder:update  <id> [--name=] [--parent=] [--json]"
    Write-Host "  folder:notes   <id> [--limit=20] [--page=1] [--json]"
    Write-Host "  config  [--token=] [--port=]"
    Write-Host "  cli:check                 Check CLI/Skill update"
    Write-Host ""
    Write-Host "For JSON output, add --json to any command."
}

if ($args.Count -eq 0) {
    Show-Usage
    exit 0
}

$cmd = $args[0]
$rest = $args[1..$args.Count]

switch ($cmd) {
    "health" { cmd_health @rest }
    "version" { cmd_version @rest }
    "list" { cmd_list @rest }
    "read" { cmd_read @rest }
    "create" { cmd_create @rest }
    "update" { cmd_update @rest }
    "search" { cmd_search @rest }
    "folders" { cmd_folders @rest }
    "folder" { cmd_folder @rest }
    "folder:create" { cmd_folder_create @rest }
    "folder:update" { cmd_folder_update @rest }
    "folder:notes" { cmd_folder_notes @rest }
    "config" { cmd_config @rest }
    "cli:check" { cmd_cli_check @rest }
    { $_ -in "-h", "--help", "help" } { Show-Usage }
    default { Write-Host "Unknown command: $cmd"; Show-Usage; exit 1 }
}