#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
findings=0

report_file() {
  local rule="$1"
  local file="$2"
  printf 'privacy finding [%s]: %s\n' "$rule" "${file#${repo_dir}/}"
  findings=$((findings + 1))
}

while IFS= read -r -d '' file; do
  case "$file" in
    "$repo_dir/.git/"*) continue ;;
    "$repo_dir/scripts/audit_privacy.sh") continue ;;
  esac

  base="${file##*/}"
  case "$base" in
    .notes-cli.conf|.env|.env.*|*.db|*.db-*|*.sqlite|*.sqlite3|*.pem|*.key|*.p12|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*)
      report_file "forbidden-file" "$file"
      continue
      ;;
  esac

  if ! file "$file" | grep -q 'text'; then
    continue
  fi

  if LC_ALL=C grep -Eq '/Users/[^/[:space:]]+|/home/[^/[:space:]]+' "$file"; then
    report_file "user-home-path" "$file"
  fi
  if LC_ALL=C grep -Eqi 'github_pat_|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}' "$file"; then
    report_file "known-secret-pattern" "$file"
  fi
  if LC_ALL=C grep -Eq "NOTES_TOKEN[[:space:]]*=[[:space:]]*['\"]?[A-Za-z0-9+/]{32,}={0,2}['\"]?" "$file"; then
    report_file "embedded-notes-token" "$file"
  fi
  if LC_ALL=C grep -Eq '^[A-Za-z0-9+/]{40,}={0,2}$' "$file"; then
    report_file "standalone-base64-value" "$file"
  fi
done < <(find "$repo_dir" -type f -print0)

if [[ "$findings" -ne 0 ]]; then
  printf 'Privacy audit failed with %s finding(s). Matched values were not printed.\n' "$findings" >&2
  exit 1
fi

printf '%s\n' 'Privacy audit passed: no blocked files, local user paths, or common credential patterns found.'
