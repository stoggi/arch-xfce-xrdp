#!/bin/bash
set -euxo pipefail

# Populate the user's home on first run (fresh volume).
if [ ! -f /home/user/.bashrc ]; then
    cp -a /etc/skel/. /home/user/
    chown -R user:user /home/user
fi

# Login password for the rdesktop user. Override via RDESKTOP_PASSWORD env.
echo "user:${RDESKTOP_PASSWORD:-user}" | chpasswd

# GPU access: host device GIDs rarely match any group inside the container.
# Synthesize a group for any host GID that isn't named in /etc/group, then
# add the user to whichever group actually owns each /dev/dri node.
shopt -s nullglob
for dev in /dev/dri/render* /dev/dri/card*; do
    gid=$(stat -c '%g' "$dev")
    if ! getent group "$gid" >/dev/null 2>&1; then
        groupadd -g "$gid" "gpu-host-$gid" || true
    fi
    group=$(getent group "$gid" 2>/dev/null | awk -F: '{print $1}') || true
    if [ -n "$group" ] && ! id -nG user | grep -qw "$group"; then
        usermod -aG "$group" user
        echo "[gpu] added user to $group (GID $gid) for $dev"
    fi
done
shopt -u nullglob

# XDG_RUNTIME_DIR for the user's session (no pam_systemd here to create it).
install -d -m 0700 -o user -g user /run/user/1000

# xrdp expects these runtime paths to exist and be writable.
mkdir -p /var/run/xrdp
chmod 0755 /var/run/xrdp
install -d -m 3777 /var/run/xrdp/sockdir

# Generate xrdp RSA keys on first run.
[ -f /etc/xrdp/rsakeys.ini ] || xrdp-keygen xrdp auto

# sesman in background, xrdp in foreground as PID 1.
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
trap 'kill "$SESMAN_PID" 2>/dev/null || true' EXIT TERM INT

exec /usr/sbin/xrdp --nodaemon
