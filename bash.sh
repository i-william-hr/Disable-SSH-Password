#!/usr/bin/env bash
set -euo pipefail

# --- sanity ---
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo -i or sudo bash secure-ssh-root.sh)"; exit 1
fi
command -v sshd >/dev/null || { echo "sshd not found"; exit 1; }

host="$(hostname)"
readout() {
  sshd -T -C user=root,host="$host",addr=127.0.0.1
}

# --- effective config snapshot ---
echo "Reading effective sshd config for root..."
eff="$(readout)"
perm_root_login="$(grep -E '^permitrootlogin ' <<<"$eff" | awk '{print $2}')"
pass_auth="$(grep -E '^passwordauthentication ' <<<"$eff" | awk '{print $2}')"
pubkey_auth="$(grep -E '^pubkeyauthentication ' <<<"$eff" | awk '{print $2}')"

echo "Effective for root: PermitRootLogin=$perm_root_login  PasswordAuthentication=$pass_auth  PubkeyAuthentication=$pubkey_auth"

# --- key checks ---
ak="/root/.ssh/authorized_keys"
if [[ ! -s "$ak" ]]; then
  echo "ABORT: $ak is missing or empty. Add at least one key for root, then re-run."
  exit 2
fi
if [[ "$pubkey_auth" != "yes" ]]; then
  echo "ABORT: PubkeyAuthentication is not enabled (effective=$pubkey_auth)."
  echo "Enable key auth first, then re-run."
  exit 3
fi

# --- determine if root password login is enabled ---
root_pw_enabled="no"
if [[ "$perm_root_login" == "yes" && "$pass_auth" == "yes" ]]; then
  root_pw_enabled="yes"
fi

if [[ "$root_pw_enabled" == "no" ]]; then
  echo "OK: Root password login is NOT enabled (either PermitRootLogin != yes or PasswordAuthentication != yes)."
  exit 0
fi

echo "WARNING: Root password login appears ENABLED."
echo "  PermitRootLogin=$perm_root_login and PasswordAuthentication=$pass_auth"
echo

read -r -p "Disable root password login now? [y/N] " ans
ans="${ans,,}"
if [[ "$ans" != "y" && "$ans" != "yes" ]]; then
  echo "No changes made."
  exit 0
fi

# --- apply hardening via drop-in (preferred over in-place edits) ---
dir="/etc/ssh/sshd_config.d"
file="$dir/zzz-disable-root-password.conf"

mkdir -p "$dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup="/etc/ssh/sshd_config.backup.$timestamp"
cp -a /etc/ssh/sshd_config "$backup" || true

cat > "$file" <<'EOF'
# Managed by secure-ssh-root.sh
# Disable password authentication, allow keys; disallow root password but allow keys.
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF

# --- validate then (re)load ---
echo "Validating sshd configuration..."
if ! sshd -t; then
  echo "ERROR: sshd -t failed. Restoring previous state."
  rm -f "$file"
  exit 4
fi

# Systemd-friendly reloads (cover Debian/Ubuntu variants)
if command -v systemctl >/dev/null; then
  systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || systemctl try-reload-or-restart ssh 2>/dev/null || true
else
  service ssh reload 2>/dev/null || service sshd reload 2>/dev/null || true
fi

# --- show final effective config ---
neweff="$(readout)"
n_perm_root_login="$(grep -E '^permitrootlogin ' <<<"$neweff" | awk '{print $2}')"
n_pass_auth="$(grep -E '^passwordauthentication ' <<<"$neweff" | awk '{print $2}')"
n_pubkey_auth="$(grep -E '^pubkeyauthentication ' <<<"$neweff" | awk '{print $2}')"

echo "Post-reload effective settings for root:"
echo "  PermitRootLogin=$n_perm_root_login  PasswordAuthentication=$n_pass_auth  PubkeyAuthentication=$n_pubkey_auth"
echo
echo "Done. Backup of sshd_config: $backup"
echo "Drop-in written to: $file"
