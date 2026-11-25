#!/usr/bin/env bash
# Muestra el HEAD de GitHub y GitLab para comprobar el espejo bidireccional.
# Requiere: GH_TOKEN, GITLAB_TOKEN, GITHUB_REPO, GITLAB_REPO.
set -euo pipefail

: "${GH_TOKEN:?Falta GH_TOKEN}"
: "${GITLAB_TOKEN:?Falta GITLAB_TOKEN}"
: "${GITHUB_REPO:=BENDER35/sc-lab-win-loc}"
: "${GITLAB_REPO:=BENDER_5000/sc-lab-win-loc}"
BRANCH="${1:-main}"

gh_head="$(git ls-remote "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPO}.git" "refs/heads/${BRANCH}" | awk '{print $1}')"
gl_head="$(git ls-remote "https://oauth2:${GITLAB_TOKEN}@gitlab.com/${GITLAB_REPO}.git" "refs/heads/${BRANCH}" | awk '{print $1}')"

printf 'GitHub  %s  %s\n' "$BRANCH" "$gh_head"
printf 'GitLab  %s  %s\n' "$BRANCH" "$gl_head"
if [[ "$gh_head" == "$gl_head" && -n "$gh_head" ]]; then
  echo 'RESULTADO: sincronizados ✓'
else
  echo 'RESULTADO: DESINCRONIZADOS ✗'
  exit 1
fi
