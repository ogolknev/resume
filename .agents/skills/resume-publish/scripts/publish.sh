#!/usr/bin/env bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
[[ $(git -C "$repo_root" branch --show-current) == main ]] || { echo 'Publish only from main.' >&2; exit 1; }
[[ -z $(git -C "$repo_root" status --porcelain) ]] || { echo 'Commit or discard working-tree changes first.' >&2; exit 1; }

for command_name in pnpm git gh curl rsync cmp; do
	command -v "$command_name" >/dev/null || { echo "Missing command: $command_name" >&2; exit 1; }
done

origin_url=$(git -C "$repo_root" remote get-url origin)
case "$origin_url" in
	git@github.com:*) repo_slug=${origin_url#git@github.com:} ;;
	https://github.com/*) repo_slug=${origin_url#https://github.com/} ;;
	*) echo "Unsupported origin: $origin_url" >&2; exit 1 ;;
esac
repo_slug=${repo_slug%.git}

pnpm --dir "$repo_root" build
git -C "$repo_root" push origin main
git -C "$repo_root" fetch origin

deploy_root=$(mktemp -d /tmp/resume-publish.XXXXXX)
deploy_tree="$deploy_root/site"
cleanup() {
	[[ ! -d "$deploy_tree" ]] || git -C "$repo_root" worktree remove --force "$deploy_tree" >/dev/null 2>&1 || true
	rmdir "$deploy_root" 2>/dev/null || true
}
trap cleanup EXIT

git -C "$repo_root" worktree add --detach "$deploy_tree" origin/gh-pages
rsync --archive --delete --exclude='.git' "$repo_root/dist/" "$deploy_tree/"
git -C "$deploy_tree" add --all

if git -C "$deploy_tree" diff --cached --quiet; then
	deploy_commit=$(git -C "$deploy_tree" rev-parse HEAD)
else
	source_commit=$(git -C "$repo_root" rev-parse --short HEAD)
	git -C "$deploy_tree" commit -m "Deploy resume from $source_commit"
	deploy_commit=$(git -C "$deploy_tree" rev-parse HEAD)
	git -C "$deploy_tree" push origin HEAD:gh-pages
fi

pages_url=$(gh api "repos/$repo_slug/pages" --jq '.html_url')
pages_ready=''
for attempt in {1..20}; do
	pages_state=$(gh api "repos/$repo_slug/pages/builds/latest" --jq '[.status, .commit, (.error.message // "")] | @tsv')
	IFS=$'\t' read -r pages_status pages_commit pages_error <<<"$pages_state"
	[[ -z "$pages_error" ]] || { echo "$pages_error" >&2; exit 1; }
	if [[ "$pages_status" == built && "$pages_commit" == "$deploy_commit" ]]; then
		pages_ready=1
		break
	fi
	sleep 2
done
[[ -n "$pages_ready" ]] || { echo 'GitHub Pages did not finish in time.' >&2; exit 1; }

pages_url=${pages_url%/}/
curl --fail --silent --show-error --location --output "$deploy_root/live.html" "${pages_url}?v=${deploy_commit:0:12}"
curl --fail --silent --show-error --location --output "$deploy_root/live.pdf" "${pages_url}nikita-ogolknev-resume.pdf?v=${deploy_commit:0:12}"
cmp "$deploy_tree/index.html" "$deploy_root/live.html"
cmp "$deploy_tree/nikita-ogolknev-resume.pdf" "$deploy_root/live.pdf"

printf 'main: %s\ngh-pages: %s\nURL: %s\n' "$(git -C "$repo_root" rev-parse HEAD)" "$deploy_commit" "$pages_url"
