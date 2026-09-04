#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

repo_root=$(git rev-parse --show-toplevel)
http_port=${RESUME_HTTP_PORT:-4321}
driver_port=${RESUME_WEBDRIVER_PORT:-4444}
browser_bin=${RESUME_BROWSER_BIN:-/opt/zen-browser-bin/zen-bin}
driver_bin=${RESUME_GECKODRIVER:-$(command -v geckodriver || true)}
runtime_dir=$(mktemp -d /tmp/resume-pdf.XXXXXX)
server_pid=''
driver_pid=''
session_id=''

cleanup() {
	[[ -z "$session_id" ]] || curl --silent --request DELETE "http://127.0.0.1:$driver_port/session/$session_id" >/dev/null || true
	[[ -z "$driver_pid" ]] || kill "$driver_pid" 2>/dev/null || true
	[[ -z "$server_pid" ]] || kill "$server_pid" 2>/dev/null || true
	[[ -z "$driver_pid" ]] || wait "$driver_pid" 2>/dev/null || true
	[[ -z "$server_pid" ]] || wait "$server_pid" 2>/dev/null || true
	rm -rf -- "$runtime_dir"
}

trap cleanup EXIT

for command_name in pnpm python3 curl jq base64 pdfinfo pdftotext pdftoppm install; do
	command -v "$command_name" >/dev/null || { echo "Missing command: $command_name" >&2; exit 1; }
done
[[ -x "$driver_bin" ]] || { echo 'Missing geckodriver. Install the CachyOS package or set RESUME_GECKODRIVER.' >&2; exit 1; }
[[ -x "$browser_bin" ]] || { echo 'Browser not found. Set RESUME_BROWSER_BIN.' >&2; exit 1; }

pnpm --dir "$repo_root" build
mkdir -p "$repo_root/output/pdf" "$repo_root/tmp/pdfs" "$runtime_dir/site"
ln -s "$repo_root/dist" "$runtime_dir/site/resume"

python3 -m http.server "$http_port" --bind 127.0.0.1 --directory "$runtime_dir/site" >"$runtime_dir/http.log" 2>&1 &
server_pid=$!
"$driver_bin" --port "$driver_port" --log fatal >"$runtime_dir/geckodriver.log" 2>&1 &
driver_pid=$!

for attempt in {1..40}; do
	curl --fail --silent "http://127.0.0.1:$driver_port/status" >/dev/null && break
	[[ "$attempt" != 40 ]] || { cat "$runtime_dir/geckodriver.log" >&2; exit 1; }
	sleep 0.25
done

curl --fail-with-body --silent --show-error --request POST \
	--header 'Content-Type: application/json' \
	--data-binary "{\"capabilities\":{\"alwaysMatch\":{\"browserName\":\"firefox\",\"moz:firefoxOptions\":{\"binary\":\"$browser_bin\",\"args\":[\"-headless\"]}}}}" \
	--output "$runtime_dir/session.json" "http://127.0.0.1:$driver_port/session"
session_id=$(jq --exit-status --raw-output '.value.sessionId // .sessionId' "$runtime_dir/session.json")

curl --fail-with-body --silent --show-error --request POST \
	--header 'Content-Type: application/json' \
	--data-binary "{\"url\":\"http://127.0.0.1:$http_port/resume/\"}" \
	--output "$runtime_dir/navigate.json" "http://127.0.0.1:$driver_port/session/$session_id/url"
curl --fail-with-body --silent --show-error --request POST \
	--header 'Content-Type: application/json' \
	--data-binary '{"background":true,"orientation":"portrait","scale":1,"shrinkToFit":true,"page":{"width":21,"height":29.7},"margin":{"top":0,"bottom":0,"left":0,"right":0}}' \
	--output "$runtime_dir/print.json" "http://127.0.0.1:$driver_port/session/$session_id/print"
jq --exit-status --raw-output '.value' "$runtime_dir/print.json" | base64 --decode >"$runtime_dir/resume.pdf"

pdfinfo "$runtime_dir/resume.pdf" >"$runtime_dir/pdfinfo.txt"
grep -Eq '^Pages:[[:space:]]+2$' "$runtime_dir/pdfinfo.txt"
grep -Eq '^Page size:.*A4' "$runtime_dir/pdfinfo.txt"
pdftotext -layout "$runtime_dir/resume.pdf" "$runtime_dir/resume.txt"
grep -q 'Никита Оголкнев' "$runtime_dir/resume.txt"

qa_dir=$(mktemp -d "$repo_root/tmp/pdfs/resume.XXXXXX")
pdftoppm -png -r 144 "$runtime_dir/resume.pdf" "$qa_dir/page"
install -m 0644 "$runtime_dir/resume.pdf" "$repo_root/output/pdf/nikita-ogolknev-resume.pdf"
install -m 0644 "$runtime_dir/resume.pdf" "$repo_root/public/nikita-ogolknev-resume.pdf"
install -m 0644 "$runtime_dir/resume.pdf" "$repo_root/dist/nikita-ogolknev-resume.pdf"

printf 'PDF: %s\nQA: %s\n' "$repo_root/output/pdf/nikita-ogolknev-resume.pdf" "$qa_dir"
