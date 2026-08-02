# wintermute — gaming desktop / media-server / personal lab

Gaming desktop, Sunshine host, Jellyfin server, and personal lab.
Currently running Nobara Linux; planned NixOS migration (timeline TBD).
Future NAS role planned once HDD prices allow.

---

## Hardware

| Component | Details |
|---|---|
| Motherboard | ASUS ROG Strix X570-E Gaming |
| CPU | AMD Ryzen 9 5950X |
| GPU | Radeon RX 7900 GRE |

NixOS will need **ROCm + Mesa** for the GPU (compute + gaming).

---

## Display setup

Three outputs: AV receiver, PC monitor, and a **DisplayPort dummy dongle**.
The dongle keeps a virtual display alive when no physical display is connected —
required for Sunshine to present a captureable desktop during headless sessions.

---

## Wake-on-LAN

Enables waking the machine from Moonlight before connecting.

**Requirements:**

1. **BIOS/UEFI** — enable "Wake on LAN" (may be labelled "Power on by PCI-E/PCI"
   in the power management section; varies by BIOS version).
2. **NetworkManager** — configure the wired connection to keep magic-packet WoL
   active across reboots:
   ```bash
   nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
   nmcli connection up "Wired connection 1"
   ```
   Verify: `sudo ethtool <iface> | grep -A2 "Wake-on"` → should show `g`.

Moonlight sends the magic packet automatically when you attempt to connect to a
sleeping host — no extra client-side config needed.

> **Note:** WoL from full power-off requires auto-login so that Sunshine starts
> with the graphical session. From suspend, the existing session resumes and
> Sunshine is already running.

---

## Sunshine (remote gaming)

System package: `/usr/bin/sunshine`

A user systemd service ships with the package:

```
app-dev.lizardbyte.app.Sunshine.service   (alias: sunshine.service)
```

**Enable on startup:**

```bash
systemctl --user enable app-dev.lizardbyte.app.Sunshine.service
```

The service depends on `graphical-session.target` — auto-login is needed for
Sunshine to start without a manual login after boot/wake.

**NixOS:** will need a NixOS module or a custom user service; keep regardless
of which DE is chosen.

---

## Media server (`~/media-server`)

Podman-compose stack:

- **Jellyfin** — media library, exposed internally only
- **Cloudflare tunnel** — remote access without port-forwarding

Managed via a systemd user service (`media-server.service`) with lingering
enabled. The service has a `BindsTo=mnt-media.mount` dependency that does not
propagate correctly from user context to the system mount — this binding should
be dropped or redesigned on NixOS.

Jellyfin config and database are backed up externally.

**NixOS:** NixOS module vs. container approach TBD. External config backup
could migrate to the self-hosted Nextcloud instance if needed.

---

## NixOS migration notes

- **DE:** undecided — do not bake in Plasma-specific config
- **GPU drivers:** ROCm + Mesa (see [Hardware](#hardware))
- **Sunshine:** NixOS module or custom user service
- **Jellyfin:** module vs. container TBD; see [Media server](#media-server-media-server)
- **NAS:** role and software TBD
