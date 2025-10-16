# secure-ssh-root.sh

A small Bash utility that checks if **root password login** is enabled on your Debian or Ubuntu system, verifies that **SSH key authentication** is working, and optionally disables password-based root login safely.

---

## 🧩 Features

- Detects *effective* SSH configuration using `sshd -T` (respects `Match` blocks and includes).  
- Verifies that:
  - `/root/.ssh/authorized_keys` exists and is non-empty.
  - `PubkeyAuthentication yes` is active.
- Warns if root password login is enabled (`PermitRootLogin yes` and `PasswordAuthentication yes`).
- If confirmed, disables root password login via a clean **drop-in config file** (`/etc/ssh/sshd_config.d/zzz-disable-root-password.conf`).
- Tests configuration with `sshd -t` before reloading SSH.
- Automatically reloads `sshd`/`ssh` using `systemctl` or `service`.

---

## ⚙️ Usage

1. Download or copy the script:

2. Run it as root:
   ```bash secure-ssh-root.sh
   ```

3. The script will:
   - Show the effective SSH configuration for root.
   - Abort if public key authentication isn’t enabled or `/root/.ssh/authorized_keys` is empty.
   - Ask whether you want to disable root password login if it’s currently enabled.

4. If you choose **Yes**, it:
   - Creates a drop-in file to disable password login.
   - Tests the SSH config with `sshd -t`.
   - Reloads SSH automatically.

---

## 🔒 What It Changes

If confirmed, this file is added:

```
/etc/ssh/sshd_config.d/zzz-disable-root-password.conf
```

Content:
```bash
# Managed by secure-ssh-root.sh
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
```

A backup of your main SSH config is created at:
```
/etc/ssh/sshd_config.backup.<timestamp>
```

---

## 🧠 Notes

- Safe to re-run anytime — it only modifies the drop-in file if needed.
- Aborts automatically to prevent lockout if no valid key authentication is found.
- Compatible with Debian 10+, Ubuntu 20.04+, and derivatives using `systemd` or `service`.

---

## ⚠️ Disclaimer

Use at your own risk.  
Always make sure you can log in via SSH key **before disabling password authentication**.
