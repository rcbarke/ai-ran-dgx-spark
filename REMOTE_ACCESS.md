# DGX Spark – Remote Access

> **Note:** Clemson’s internal network disables mDNS, which is required to connect via host name. Use **NVIDIA Access**’s **IP connection** instead.

The Spark is allocated an IP via **DHCP**. CCIT has advised the address will **persist** as long as the Spark remains connected to the **same NIC/port**.

---

## Devices

### DGX Spark 1
- **IP:** `A.B.C.D`
- **Hostname:** `spark-ecf8`
- **Username:** `<your-username>` 
- **Password:** `<your-password>`

> Reference [`first-boot/README.md`](./first-boot/README.md) for instructions on creating a login.

### DGX Spark 2
*(TBD)*

### DGX Spark 3
*(TBD)*

> **Multi-NIC reminder:** Spark presents several interfaces (1× 10G Ethernet, 2× QSFP ConnectX-7, plus internal bridges). **Register every physical NIC MAC** at https://netregistration.clemson.edu/ to avoid eccentric DHCP/security behavior. The utility `first-boot/display_ethernet_mac.sh` is useful for discovering physical MACs.

---

## NVIDIA Access (Remote desktop/terminal/file transfer)

Follow NVIDIA’s guide:
- https://build.nvidia.com/spark/connect-to-your-spark/overview

NVIDIA Access uses **SSH under the hood** but does **not** create `~/.ssh/config` for you.

---

## SSH setup

### Windows 10/11 (PowerShell)
1. **Check/OpenSSH client**
   ```powershell
   ssh -V
   # If missing:
   Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
   ```
2. **Initialize `~/.ssh` and config**
    ```powershell
    New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
    New-Item -ItemType File -Force "$env:USERPROFILE\.ssh\config" | Out-Null
    icacls "$env:USERPROFILE\.ssh" /inheritance:r
    icacls "$env:USERPROFILE\.ssh" /grant:r "$($env:USERNAME):(OI)(CI)F"
    icacls "$env:USERPROFILE\.ssh" /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "$($env:USERNAME):(OI)(CI)F"
    icacls "$env:USERPROFILE\.ssh"
    ```
3. **(Recommended) Create a key**
    ```powershell
    ssh-keygen -t ed25519 -C "lab-laptop" -f "$env:USERPROFILE\.ssh\id_ed25519"
    ```
    
### macOS / Linux

OpenSSH is included by default.

```bash
ssh -V
mkdir -p ~/.ssh && touch ~/.ssh/config
chmod 700 ~/.ssh && chmod 600 ~/.ssh/config
# Optional key:
ssh-keygen -t ed25519 -C "lab-laptop"
```

---

## Off-campus access (CUVPN)

Some Clemson services require your machine to appear “on campus.” When NVIDIA Access/SSH can't reach your DGX Spark, connect through **CUVPN**.

**Official page:** [https://forever.clemson.edu/di/vpn](https://forever.clemson.edu/di/vpn)

**Prereqs**

* Enroll in **Duo** (two-factor) first.
* Install **Cisco AnyConnect** (the web flow will offer it automatically).

**Quick start**

1. Open a browser → go to **`https://cuvpn.clemson.edu`**
2. Sign in with your Clemson username/password → approve Duo → **Continue**
3. If prompted, allow the web installer to install **Cisco AnyConnect** (or download and run the installer manually)
4. Launch **Cisco AnyConnect** → set VPN server to **`cuvpn.clemson.edu`** → **Connect**
5. Duo prompt options for the “Passcode” field:
   * `push` (approve on phone)
   * `phone` (voice call)
   * `sms` (text code)
   * 6-digit **app passcode** (works offline)
6. Accept the welcome banner → you’re on the campus network.
7. **Disconnect** from the same icon when finished.

> Tip: Use CUVPN only when a site demands campus IP. For GUI/terminal and file copy, **NVIDIA Access + SSH** usually suffice. 
