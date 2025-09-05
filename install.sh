cat >/tmp/install.sh <<'SH'
#!/bin/sh
# install.sh - OpenWrt/BusyBox friendly (tanpa 'install')
set -eu

BASE_URL="${1:-https://raw.githubusercontent.com/Hnatta/hgledone/refs/heads/main}"

need_root(){ [ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }; }
fetch(){ # $1=url $2=dest
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"; else wget -qO "$2" "$1"; fi
}

need_root

echo "[1/4] Pasang /usr/sbin/hgled ..."
mkdir -p /usr/sbin && chmod 0755 /usr/sbin
fetch "$BASE_URL/files/usr/sbin/hgled" /usr/sbin/hgled
chmod 0755 /usr/sbin/hgled

echo "[2/4] Buat shim hgledon & alias hged ..."
cat >/usr/sbin/hgledon <<'E'
#!/bin/sh
exec /usr/sbin/hgled "$@"
E
chmod 0755 /usr/sbin/hgledon
[ -e /usr/sbin/hged ] || ln -s /usr/sbin/hgled /usr/sbin/hged

echo "[3/4] Sisipkan blok ke /etc/rc.local ..."
if [ ! -f /etc/rc.local ]; then
  cat >/etc/rc.local <<'E'
#!/bin/sh
# Local startup
exit 0
E
  chmod 0755 /etc/rc.local
fi
# hapus blok lama jika ada
sed -i '/^# >>> hgledlan start$/,/^# <<< hgledlan end$/d' /etc/rc.local

SNIP='# >>> hgledlan start
sleep 2
/usr/sbin/hgledon -power off || true
/usr/sbin/hgledon -lan off   || true
sleep 20
/usr/sbin/hgled -r           || true
# <<< hgledlan end'

# sisipkan sebelum exit 0
if grep -q '^exit 0$' /etc/rc.local; then
  awk -v snip="$SNIP" 'BEGIN{d=0} /^exit 0$/ && !d {print snip; d=1} {print}' /etc/rc.local >/tmp/rc.local.new
  mv /tmp/rc.local.new /etc/rc.local
else
  printf '%s\nexit 0\n' "$SNIP" >>/etc/rc.local
fi
chmod 0755 /etc/rc.local

echo "[4/4] Start hgled -r sekarang ..."
/usr/sbin/hgled -s >/dev/null 2>&1 || true
/usr/sbin/hgled -r || true

echo "=== DONE ==="
echo "Cek: ps w | grep '[h]gled -l' ; cat /var/run/internet-indicator.state"
SH
sh /tmp/install.sh
