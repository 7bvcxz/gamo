#!/usr/bin/env bash
# After a push: waits for GitHub Pages to serve the new build and smoke-tests
# it, then waits for the momonium CI run of HEAD and reports its jobs.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
"$HERE/tools/verify_pages.sh" 2>&1 | tail -n 4
pages=${PIPESTATUS[0]}
sha="$(git -C "$ROOT" rev-parse HEAD)"
rid=""
for _ in $(seq 1 30); do
  rid=$(gh run list --repo 7bvcxz/gamo --workflow momonium.yml --commit "$sha" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)
  [[ -n "$rid" ]] && break
  sleep 10
done
if [[ -z "$rid" ]]; then echo "CI: no run for ${sha:0:8}"; exit 3; fi
gh run watch "$rid" --repo 7bvcxz/gamo --exit-status --interval 20 >/dev/null 2>&1
gh run view "$rid" --repo 7bvcxz/gamo --json conclusion,jobs -q '"CI run '"$rid"' " + .conclusion + " | " + ([.jobs[] | .name + ":" + .conclusion] | join(", "))'
ci=$(gh run view "$rid" --repo 7bvcxz/gamo --json conclusion -q .conclusion)
[[ $pages -eq 0 && "$ci" == "success" ]]
