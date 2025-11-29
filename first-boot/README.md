# DGX Spark — First Boot Guide

> **Scope:** Day-0 provisioning for a new DGX Spark in the lab. Covers campus network, base users, remote access, Docker/NGC setup, and sanity checks.

---

## System-Level Provisioning

1. **Cable up (out-of-box):**
   Connect **HDMI → HDMI**, **Ethernet**, **mouse**, **keyboard**. Peripherals must be **USB-C** or via a **USB-C ⇄ USB-A hub**. *Do not* use HDMI→DisplayPort adapters (unidirectional).

2. **Run NVIDIA’s OOBE (first-boot) flow:**
   If asked to configure Wi-Fi, use a **personal hotspot** only. Do **not** use `eduroam` or `clemsonguest`. Clemson’s PEAP Wi-Fi requires OS-level setup and is unreliable during first-boot. (Ref: Clemson KB article.) Prefer **wired Ethernet**.

3. **Provision the *shared lab* admin account (do not bind sudo to a personal account):**

   * **Username:** `<your-lab>`
   * **Password:** `<your-password>`
     You can add your personal account later (see *User-Level Provisioning*). Changing the primary sudo user later is painful and requires low-level OS configuration with a temporary user.

4. **Clone this repo and register MACs:**

   ```bash
   https://github.com/rcbarke/aerial-dgx-spark
   cd aerial-dgx-spark
   ./first-boot/display_ethernet_mac.sh
   ```

   Register **all physical Ethernet MACs** at: [https://netregistration.clemson.edu/](https://netregistration.clemson.edu/)
   *If you skip this, campus security will block the device within ~1 hour.*

5. **Verify campus addressing:**
   When correctly provisioned you’ll receive a **130.127.X.X** address via **persistent DHCP** (sticky to the switch port). This IP is your primary remote-access endpoint. See `../REMOTE_ACCESS.md` for NVIDIA Access/SSH details.

6. **Disable Wi-Fi to avoid split routing and portal loops:**

   ```bash
   ./first-boot/disable_wifi.sh
   ```

   This shuts the wireless adapter off now and on every reboot.

---

## User-Level Provisioning

1. **Create your personal login (from `is-win`):**

   ```bash
   # Replace <you> with your username
   sudo adduser <you>
   sudo usermod -aG sudo <you>           # admin rights
   sudo usermod -aG docker <you>         # run docker without sudo (log out/in to take effect)
   ```
2. **Log into your account** and set a strong password.
3. **Firefox homepage:** set to [https://build.nvidia.com/spark](https://build.nvidia.com/spark) and sign into your NVIDIA account (daily tutorials, docs, and forums).
4. **Install VS Code (Spark guide):**
   [https://build.nvidia.com/spark/vscode](https://build.nvidia.com/spark/vscode) — then **pin** to the task tray.
5. **DGX Dashboard + JupyterLab:**
🔗 [DGX Dashboard Portal → https://build.nvidia.com/spark/dgx-dashboard](https://build.nvidia.com/spark/dgx-dashboard)

**Known multi-user setup quirk**

Each new Linux user must have an entry in
`/opt/nvidia/dgx-dashboard-service/jupyterlab_ports.yaml`:

```yaml
users:
    - username: nobody
      jupyterlab_port: 11001
    - username: is-win
      jupyterlab_port: 11002
    - username: <your-username>
      jupyterlab_port: <unique-port>
```

After editing, reboot the DGX Spark.

Then prepare the Lab root:

```bash
sudo mkdir -p /home/<user>/jupyterlab
sudo chown -R <user>:<user> /home/<user>/jupyterlab
```

---

**JupyterLab launch behavior**

* ✅ `/home/<user>/jupyterlab/` **must exist**
* 🚫 Your working directory **must not exist** yet (Dashboard creates it automatically)

**Example**

To start a project named `test`:

```bash
/home/<user>/jupyterlab/        # exists
/home/<user>/jupyterlab/test/   # does NOT exist
```

Then, in DGX Dashboard → JupyterLab, set working dir = `test` and click **Start**.
The service will create the environment, virtual env, and dependencies automatically.

---

## Docker

1. **(Recommended) Enable docker without sudo**

   ```bash
   sudo usermod -aG docker "$USER"
   # log out and back in for group membership to take effect
   ```
2. **Docker Hub login** *(to avoid pull limits)*

   ```bash
   docker login
   # Username: <docker-username>
   # Password: <docker-password>
   ```
---

## NGC Provisioning (for NVIDIA Aerial)

> NVIDIA Aerial artifacts are distributed via **NVIDIA GPU Cloud (NGC)**. You need the **NGC CLI** and a **Personal API Key**.

1. **Install NGC CLI (ARM64):**
   ```bash
   ./first-boot/install_ngc_cli.sh
   ngc --version    # should print NGC CLI x.y.z
   ```

2. **Configure NGC CLI (defaults + API key, secure storage):**

   ```bash
   ./first-boot/configure_ngc_cli.sh
   ```

   * The script prompts for your **NGC API key** and sets the default org to **`aerial-ov-digital-twin (esee5uzbruax)`**.
   * **Security:** Your API key is **not written** to `~/.ngc/config`; it is stored in your OS **keyring/credential store**.
     The config file only holds non-secret preferences (e.g., `org`, `team`, `format_type`).

3. **Docker authentication to NGC (nvcr.io):**

   * The script **automatically runs** `docker login nvcr.io` using your API key (username: `$oauthtoken`).
   * If you ever need to re-authenticate manually:

     ```bash
     docker login nvcr.io
     # Username: $oauthtoken
     # Password: <Your NGC API Key>
     ```

---

## Sanity Checks

```bash
# Network & registration
ip -4 addr show dev <ethX>
curl -I https://www.nvidia.com | head -n1

# Remote access (from your laptop)
ssh <your-username>@130.127.X.X     # or use NVIDIA Access per REMOTE_ACCESS.md

# Docker
docker run --rm hello-world

# NGC CLI
ngc --version
ngc user who --format_type ascii
ngc registry image list nvidia/cuda | head
```

---

## Troubleshooting

* **Portal loop / SSL errors:** Ensure you registered **Ethernet MACs** (not Wi-Fi) at netreg for **all** physical NICs. Disable Wi-Fi.
* **Remote access fails in NVIDIA Access:** Ensure `~/.ssh/config` exists on your laptop and that OpenSSH is installed. See `../REMOTE_ACCESS.md`.
* **`ngc` not found:** Re-run `./first-boot/install_ngc_cli.sh` and confirm it places a symlink in `/usr/local/bin` or that `~/.local/bin` is on your `$PATH`. Run `hash -r` after installation.
* **Docker requires sudo:** You didn’t relogin after `usermod -aG docker`. Log out/in (or reboot).

---

## Change Log

* 2025-11-28: Generic public access version (removed private information).
* 2025-11-07: Initial version (first-boot flow, MAC registration, Wi-Fi disable, Docker/NGC setup).
* 2025-11-07: Fixes for secure docker login.
