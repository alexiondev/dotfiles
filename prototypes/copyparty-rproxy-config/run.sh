#!/usr/bin/env bash

set -euo pipefail

bold=$'\033[1m'
reset=$'\033[0m'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state" "$tmp/root"

printf '%sQuestion%s\n' "$bold" "$reset"
printf 'Does the proposed copyparty reverse-proxy config parse and make a proxied HTTPS-origin login-shaped request pass the CORS gate?\n\n'

printf '%sNix-generated config fragment%s\n' "$bold" "$reset"
config_script=$(nix eval --raw '.#nixosConfigurations.pikachu.config.containers.copyparty.config.systemd.services.copyparty.serviceConfig.ExecStartPre')
awk '/\[global\]/{show=1} /\[accounts\]/{show=0} show {print}' "$config_script" | grep -E 'rproxy|xff-hdr|xff-src' || true

pkg=$(nix eval --raw '.#nixosConfigurations.pikachu.config.containers.copyparty.config.modules.services.copyparty.package.outPath')

make_conf() {
  local file=$1 port=$2 rproxy=$3
  cat > "$file" <<EOF
[global]
  i: 127.0.0.1
  p: $port
  usernames
  http-only
  no-crt
  no-thumb
  no-snap
  no-rescan
  ses-db: $tmp/state/sessions-$port.db
  chpw-db: $tmp/state/chpw-$port.json
  shr-db: $tmp/state/shares-$port.db
$rproxy

[accounts]
  alexion: prototype-password

[/]
  $tmp/root
  accs:
    A: alexion
EOF
}

start_server() {
  local conf=$1 log=$2
  "$pkg/bin/copyparty" -c "$conf" >"$log" 2>&1 &
  local pid=$!
  for _ in {1..50}; do
    if grep -q 'listening' "$log"; then
      printf '%s' "$pid"
      return 0
    fi
    sleep 0.1
  done
  cat "$log"
  kill "$pid" 2>/dev/null || true
  return 1
}

request() {
  local label=$1 port=$2 host=$3 proto=${4:-}
  local headers="$tmp/$label.headers"
  local body="$tmp/$label.body"
  local args=(
    -sS
    -D "$headers"
    -o "$body"
    -X POST
    -H "Host: $host"
    -H 'Origin: https://files.alexion.dev'
    -H 'X-Forwarded-For: 10.23.20.20'
  )
  if [[ -n "$proto" ]]; then
    args+=(-H "X-Forwarded-Proto: $proto")
  fi
  curl "${args[@]}" "http://127.0.0.1:$port/?pw=alexion:prototype-password" >/dev/null || true
  printf '%-24s %s %s\n' "$label" "$(head -1 "$headers" | tr -d '\r')" "$(head -1 "$body")"
}

rproxy_config='  rproxy: 1
  xff-hdr: x-forwarded-for
  xff-src: 127.0.0.1/32'
make_conf "$tmp/rproxy.conf" 39234 "$rproxy_config"
pid=$(start_server "$tmp/rproxy.conf" "$tmp/rproxy.log")

printf '\n%sCORS gate probes%s\n' "$bold" "$reset"
request with-forwarded-https 39234 files.alexion.dev https
request missing-forwarded-proto 39234 files.alexion.dev
request wrong-forwarded-host 39234 '10.23.20.126:3923' https

kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true

printf '\n%sRelevant server log%s\n' "$bold" "$reset"
grep -E 'cors-reject|POST|http405|got proxied request|untrusted source|listening' "$tmp/rproxy.log" || true

printf '\n%sNginx proxy headers%s\n' "$bold" "$reset"
toplevel=$(nix build --print-out-paths '.#nixosConfigurations.pikachu.config.containers.reverse-proxy.config.system.build.toplevel' --no-link)
nginx_conf=$(readlink -f "$toplevel/etc/nginx/nginx.conf")
include_path=$(awk '/server_name files\.alexion\.dev;/{in_server=1} in_server && /include .*recommended-proxy_set_header/{print $2; exit}' "$nginx_conf" | tr -d ';')
cat "$include_path"
