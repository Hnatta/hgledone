
#!/bin/sh
# install.sh — pasang /usr/sbin/hgled dari files/usr/sbin/hgled + atur rc.local + jalankan hgled -r
# Kompatibel: OpenWrt/BusyBox
set -eu

# Ubah BASE_URL jika perlu; default mengarah ke repo kamu
BASE_URL="${1:-https://raw.githubusercontent.com/Hnatta/hgledone/main}"

need_root() { [ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }; }
download() {
  # $1=url  $2=dest
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  else
    wget -qO "$2" "$1"
  fi
}

need_root

echo "[1/4] Mengunduh & memasang /usr/sbin/hgled ..."
install -d -m 0755 /usr/sbin
# ambil file utama dari path: files/usr/sbin/hgled
download "$BASE_URL/files/usr/sbin/hgled" /usr/sbin/hgled
chmod 0755 /usr/sbin/hgled

echo "[2/4] Membuat shim /usr/sbin/hgledon & alias /usr/sbin/hged ..."
# Shim agar perintah hgledon tetap tersedia (meneruskan ke hgled satu file)
cat > /usr/sbin/hgledon <<'EOF_HGLEDON'
#!/bin/sh
exec /usr/sbin/hgled "$@"
EOF_HGLEDON
chmod 0755 /usr/sbin/hgledon
# Alias opsional untuk typo "hged"
[ -e /usr/sbin/hged ] || ln -s /usr/sbin/hgled /usr/sbin/hged

echo "[3/4] Menyisipkan blok paksa ke /etc/rc.local ..."
# Pastikan rc.local ada
if [ ! -f /etc/rc.local ]; then
  cat > /etc/rc.local <<'EOF_RC'
#!/bin/sh
# Local startup
exit 0
EOF_RC
  chmod 0755 /etc/rc.local
fi

# Hapus blok lama (jika pernah disisipkan)
sed -i '/^# >>> hgledlan start$/,/^# <<< hgledlan end$/d' /etc/rc.local

# Snippet sesuai format permintaanmu
SNIP='# >>> hgledlan start
sleep 2
/usr/sbin/hgledon -power off || true
/usr/sbin/hgledon -lan off   || true
sleep 20
/usr/sbin/hgled -r           || true
# <<< hgledlan end'

# Sisipkan sebelum "exit 0" (atau tambahkan di akhir jika tidak ada)
if grep -q '^exit 0$' /etc/rc.local; then
  awk -v snip="$SNIP" '
    BEGIN { done=0 }
    /^exit 0$/ && !done { print snip; done=1 }
    { print }
  ' /etc/rc.local > /tmp/rc.local.new && mv /tmp/rc.local.new /etc/rc.local
else
  printf '%s\nexit 0\n' "$SNIP" >> /etc/rc.local
fi
chmod 0755 /etc/rc.local

echo "[4/4] Menjalankan hgled -r sekarang ..."
/usr/sbin/hgled -s >/dev/null 2>&1 || true
/usr/sbin/hgled -r || true

echo "== Selesai =="
echo "Cek proses:   ps w | grep '[h]gled -l'"
echo "Cek status:   cat /var/run/internet-indicator.state   # online/offline"
echo "Startup blok ditambahkan ke /etc/rc.local."
