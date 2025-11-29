# --- Disable Wi‑Fi now and at every boot on DGX Spark ---

# 1) Drop any saved Wi‑Fi connections and turn off the radio (ignore if NM not present)
if command -v nmcli >/dev/null 2>&1; then
  sudo nmcli -t -f NAME,TYPE connection show \
    | awk -F: '$2=="wifi"{print $1}' \
    | xargs -r -I{} sudo nmcli connection delete "{}"
  sudo nmcli radio wifi off || true
fi

# 2) Soft‑block wireless at the kernel level and persist state
if command -v rfkill >/dev/null 2>&1; then
  sudo rfkill block wlan
  # Ensure the block state is restored automatically on every boot
  sudo systemctl enable --now systemd-rfkill.service systemd-rfkill.socket
fi

# 3) Install a tiny systemd unit that re‑applies the block at boot (belt‑and‑suspenders)
sudo tee /etc/systemd/system/disable-wifi.service >/dev/null <<'EOF'
[Unit]
Description=Disable Wi‑Fi at boot (DGX Spark)
DefaultDependencies=no
After=systemd-rfkill.service NetworkManager.service
Wants=systemd-rfkill.service

[Service]
Type=oneshot
# Use /usr/bin/env so paths work whether rfkill/nmcli are in /usr/bin or /usr/sbin
ExecStart=/usr/bin/env bash -lc 'rfkill block wlan || /usr/sbin/rfkill block wlan; nmcli radio wifi off || true'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-wifi.service

# 4) (Optional – stronger) Blacklist the active Wi‑Fi driver so the card never binds
if command -v lspci >/dev/null 2>&1; then
  DRIVER=$(lspci -nnk | awk '
  /Network controller|Wireless/ {inblk=1}
  inblk && /Kernel driver in use:/ {sub(/.*: /,""); print; exit}')
  if [ -n "$DRIVER" ]; then
    echo "blacklist $DRIVER" | sudo tee /etc/modprobe.d/blacklist-wifi.conf
    # Rebuild initramfs for your distro
    if command -v update-initramfs >/dev/null 2>&1; then
      sudo update-initramfs -u
    elif command -v dracut >/dev/null 2>&1; then
      sudo dracut -f
    fi
    # Unload the module now (non-fatal if it can't be removed while in use)
    sudo modprobe -r "$DRIVER" 2>/dev/null || true
  fi
fi

# 5) Show your wired IPv4; once registered you should see a 130.127.x.x address
if command -v nmcli >/dev/null 2>&1; then
  ETH=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2=="ethernet" && $3=="connected"{print $1; exit}')
  [ -n "$ETH" ] && ip -4 addr show "$ETH" | awk '/inet /{print "Ethernet " "'"$ETH"'" " -> " $2}'
else
  ip -4 -o addr show scope global | awk '{print $2, "->", $4}'
fi

