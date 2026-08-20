#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: build-toy-counter.sh <target-dir>}"
rm -rf "$target"
mkdir -p "$target"
cd "$target"
git init -q
git config user.email "fixture@example.com"
git config user.name "Fixture Builder"

# Commit 1: scaffold arg parsing
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

cmd="${1:-}"
case "$cmd" in
  add|show|install) ;;
  *) usage; exit 1 ;;
esac
EOF
chmod +x counter.sh
git add counter.sh
git commit -q -m "scaffold: arg parsing skeleton"

# Commit 2: pure arithmetic
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

cmd="${1:-}"
case "$cmd" in
  add|show|install) ;;
  *) usage; exit 1 ;;
esac
EOF
git add counter.sh
git commit -q -m "feat: pure arithmetic for computing new totals"

# Commit 3: local persistence
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

read_counter() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo 0
  fi
}

write_counter() {
  local file="$1" value="$2"
  echo "$value" > "$file"
}

main() {
  local cmd="${1:-}"
  local counter_file="${COUNTER_FILE:-./counter.txt}"
  case "$cmd" in
    add)
      local delta="${2:-1}"
      local current new_total
      current="$(read_counter "$counter_file")"
      new_total="$(compute_new_total "$current" "$delta")"
      write_counter "$counter_file" "$new_total"
      echo "$new_total"
      ;;
    show)
      read_counter "$counter_file"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
EOF
git add counter.sh
git commit -q -m "feat: persist counter to a local counter.txt"

# Commit 4: install subcommand (the dangerous phase)
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

read_counter() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo 0
  fi
}

write_counter() {
  local file="$1" value="$2"
  echo "$value" > "$file"
}

do_install() {
  local bin_dir="$HOME/.local/bin"
  local rc_file="$HOME/.bashrc"
  mkdir -p "$bin_dir"
  cp "$0" "$bin_dir/counter"
  chmod +x "$bin_dir/counter"
  if ! grep -q '.local/bin' "$rc_file" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
  fi
  echo "Installed to $bin_dir/counter"
}

main() {
  local cmd="${1:-}"
  local counter_file="${COUNTER_FILE:-./counter.txt}"
  case "$cmd" in
    add)
      local delta="${2:-1}"
      local current new_total
      current="$(read_counter "$counter_file")"
      new_total="$(compute_new_total "$current" "$delta")"
      write_counter "$counter_file" "$new_total"
      echo "$new_total"
      ;;
    show)
      read_counter "$counter_file"
      ;;
    install)
      do_install
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
EOF
git add counter.sh
git commit -q -m "feat: install subcommand copies script to ~/.local/bin and updates PATH in ~/.bashrc"

echo "Fixture built at $target"
