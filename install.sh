#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_skill_dir="${package_dir}/skill/office-suite-notes"
user_home="${HOME:?Cannot determine user home directory}"
cli_dir="${user_home}/.local/bin"
codex_root="${CODEX_HOME:-${user_home}/.codex}"
skill_dir="${codex_root}/skills/office-suite-notes"

required_files=(
  "${source_skill_dir}/SKILL.md"
  "${source_skill_dir}/agents/openai.yaml"
  "${source_skill_dir}/scripts/notes"
  "${source_skill_dir}/scripts/notes.ps1"
  "${source_skill_dir}/references/commands.md"
  "${source_skill_dir}/references/provenance.md"
  "${source_skill_dir}/references/setup.md"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing package file: ${required_file}" >&2
    exit 1
  fi
done

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing dependency: curl" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Missing dependency: python3" >&2
  exit 1
fi

mkdir -p "$cli_dir" "$skill_dir/agents" "$skill_dir/scripts" "$skill_dir/references"
install -m 0755 "${source_skill_dir}/scripts/notes" "${cli_dir}/notes"
install -m 0644 "${source_skill_dir}/SKILL.md" "${skill_dir}/SKILL.md"
install -m 0644 "${source_skill_dir}/agents/openai.yaml" "${skill_dir}/agents/openai.yaml"
install -m 0755 "${source_skill_dir}/scripts/notes" "${skill_dir}/scripts/notes"
install -m 0644 "${source_skill_dir}/scripts/notes.ps1" "${skill_dir}/scripts/notes.ps1"
install -m 0644 "${source_skill_dir}/references/commands.md" "${skill_dir}/references/commands.md"
install -m 0644 "${source_skill_dir}/references/provenance.md" "${skill_dir}/references/provenance.md"
install -m 0644 "${source_skill_dir}/references/setup.md" "${skill_dir}/references/setup.md"

bash -n "${cli_dir}/notes"
"${cli_dir}/notes" --help >/dev/null

echo "Installed CLI:   ${cli_dir}/notes"
echo "Installed Skill: ${skill_dir}"

case ":${PATH}:" in
  *":${cli_dir}:"*) ;;
  *) echo "Add this directory to PATH before using notes: ${cli_dir}" ;;
esac

if [[ -d /Applications/pcsuite.app ]]; then
  if "${cli_dir}/notes" health >/dev/null 2>&1; then
    echo "Office Suite Notes service: reachable"
  else
    echo "Office Suite Notes service: not reachable; open vivo Office Suite and enable Settings > Notes > CLI"
  fi
else
  echo "vivo Office Suite was not found at /Applications/pcsuite.app"
fi

echo "Next: create/copy a CLI token in vivo Office Suite, then run:"
echo "  notes config --token='<token>'"
