# rdesktop

Arch Linux + xfce4 + xrdp in a container, with Intel iGPU passthrough for
Vulkan / OpenGL (via AUR's `xorgxrdp-glamor` for DRI3 support). Built for use
as a lightweight remote dev / sandbox desktop reachable over RDP.

## What's inside

- `quay.io/toolbx/arch-toolbox:latest` base
- xfce4 + firefox, vlc, zed, micro, screen, htop, jq, git, rustup, ttf-hack
- Intel Vulkan stack (`mesa`, `vulkan-intel`, `xf86-video-intel`)
- xrdp + GLAMOR-enabled xorgxrdp, built from AUR during the image build
- pipewire-pulse for audio
- A `user` account (UID 1000) with passwordless sudo

## Requirements

- Docker with Compose (`docker compose` v2)
- Intel GPU on the host (for AMD / NVIDIA see "Other GPUs" below)
- Rootful Docker — rootless podman works in principle but needs extra
  `--gidmap` plumbing that a plain Compose file can't express

## Quick start

```
RDESKTOP_PASSWORD=changeme docker compose up -d --build
```

First build takes ~10 min (the AUR xrdp + xorgxrdp-glamor packages compile
from source). Subsequent rebuilds reuse layers.

Connect from any RDP client:

- **Host:** `<server-ip>:3389`
- **Username:** `user`
- **Password:** whatever you set `RDESKTOP_PASSWORD` to (default: `user`)

## Configuration

| Env var             | Default | Notes                                   |
| ------------------- | ------- | --------------------------------------- |
| `RDESKTOP_PASSWORD` | `user`  | Login password for the `user` account.  |

| Volume                 | Purpose                                                     |
| ---------------------- | ----------------------------------------------------------- |
| `./home:/home/user:Z`  | Persistent home directory — git repos, rustup, xfce config. |
| `/etc/localtime` (ro)  | Host timezone.                                              |

Port `3389/tcp` is exposed for RDP. `/dev/dri` is passed through for GPU.

## Verifying GPU access

After connecting via RDP, open a terminal and run:

```
vulkaninfo --summary    # should list your GPU
vkcube                  # spinning cube; requires DRI3 (i.e. glamor xorgxrdp)
```

If `vkcube` errors with "No DRI3 support detected", the `xorgxrdp-glamor`
package didn't build correctly; rebuild the image.

## Other GPUs

The Containerfile hard-codes Intel drivers. For other hardware swap:

- **AMD**: `vulkan-radeon` instead of `vulkan-intel`, `xf86-video-amdgpu`
  instead of `xf86-video-intel`, `libva-mesa-driver` instead of
  `libva-intel-driver`.
- **NVIDIA**: drop `xf86-video-intel`; add `nvidia-utils` and
  `lib32-nvidia-utils`. Also set `NVIDIA_VISIBLE_DEVICES=all` and
  `NVIDIA_DRIVER_CAPABILITIES=all` in the compose environment, and ensure
  the NVIDIA Container Toolkit is installed on the host.

## Changing the username

Replace every occurrence of `user` in `Containerfile`, `entrypoint.sh`, and
`docker-compose.yml` with the name you want. The UID (1000) matches typical
host user UIDs so bind-mounts work out of the box.

## Security notes

- Default password is `user`. Change it before exposing port 3389 to
  anything untrusted.
- The `user` account has passwordless `sudo` — convenient for a personal
  sandbox, bad idea if multiple people share this.
- RDP's built-in TLS uses a self-signed cert generated at first run; fine
  for a LAN, not for public exposure. Put this behind a VPN or SSH tunnel.
