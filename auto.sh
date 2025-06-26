#!/bin/bash

# =====================================
# 📦 AUTO INSTALL WORDPRESS
# Tanpa hardcode user, fleksibel semua environment
# =====================================

# === INPUT DOMAIN ===
read -p "Masukkan nama domain (contoh: ried500.com): " DOMAIN

# === ENV DYNAMIC ===
USER_DIR=$(whoami)
USER_HOME=$HOME
TARGET_DIR="$USER_HOME/web/$DOMAIN/public_html"
SITE_URL="http://$DOMAIN"
ADMIN_EMAIL="admin@$DOMAIN"

# === RANDOM DB & USER ===
TIMESTAMP=$(date +%s | tail -c 5)
DB_NAME="wp_${TIMESTAMP}"
DB_USER="usr_${TIMESTAMP}"
DB_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)"

WP_ADMIN_USER="admin_$(tr -dc a-z0-9 </dev/urandom | head -c 5)"
WP_ADMIN_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)_A!"
WP_EDITOR_USER="editor_$(tr -dc a-z0-9 </dev/urandom | head -c 5)"
WP_EDITOR_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)_E!"

# === CEK DIREKTORI ===
if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Folder tidak ditemukan: $TARGET_DIR"
  exit 1
fi

if [ "$(ls -A "$TARGET_DIR")" ]; then
  echo "❌ Folder $TARGET_DIR tidak kosong. Hentikan untuk mencegah overwrite."
  exit 1
fi

cd "$TARGET_DIR" || { echo "❌ Gagal masuk ke direktori target."; exit 1; }

# === DOWNLOAD WORDPRESS ===
echo "📦 Download WordPress..."
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -rf wordpress latest.tar.gz

# === BUAT DATABASE ===
echo "🗃️ Membuat database dan user: $DB_NAME"
sudo mysql <<MYSQL
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL

# === KONFIGURASI wp-config.php ===
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php
sed -i '/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d' wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# === INSTALL WP-CLI JIKA BELUM ADA ===
if ! command -v wp &> /dev/null; then
  echo "🧰 Install wp-cli..."
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  sudo mv wp-cli.phar /usr/local/bin/wp
fi

# === INSTALL WORDPRESS ===
echo "🚀 Instalasi WordPress..."
wp core install --url="$SITE_URL" --title="Site $DOMAIN" \
  --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" --skip-email --allow-root

# === TAMBAHKAN USER EDITOR ===
wp user create "$WP_EDITOR_USER" editor@$DOMAIN --role=editor --user_pass="$WP_EDITOR_PASS" --allow-root

# === LOG KE FILE ===
echo "🔐 Menyimpan konfigurasi ke .env dan install_log.txt..."
echo -e "DB_NAME=$DB_NAME\nDB_USER=$DB_USER\nDB_PASS=$DB_PASS" > "$TARGET_DIR/.env"
echo -e "ADMIN_USER=$WP_ADMIN_USER\nADMIN_PASS=$WP_ADMIN_PASS\nEDITOR_USER=$WP_EDITOR_USER\nEDITOR_PASS=$WP_EDITOR_PASS\nURL=$SITE_URL/wp-admin" > "$TARGET_DIR/install_log.txt"

# === TAMPILKAN INFO DAN COPY KE CLIPBOARD (JIKA BISA) ===
echo
echo "✅ WordPress berhasil diinstal di: $DOMAIN"
echo "🔗 Login Admin: $SITE_URL/wp-admin"
echo "   👤 Admin  : $WP_ADMIN_USER / $WP_ADMIN_PASS"
echo "   👤 Editor : $WP_EDITOR_USER / $WP_EDITOR_PASS"
echo
echo "📋 INFORMASI DATABASE:"
echo -e "🗃️  \033[1;36mDB_NAME:\033[0m $DB_NAME"
echo -e "👤 \033[1;36mDB_USER:\033[0m $DB_USER"
echo -e "🔑 \033[1;36mDB_PASS:\033[0m $DB_PASS"
echo

# === COPY KE CLIPBOARD JIKA MUNGKIN ===
CLIP_CMD=""
if command -v xclip &> /dev/null; then
  CLIP_CMD="xclip -selection clipboard"
elif command -v pbcopy &> /dev/null; then
  CLIP_CMD="pbcopy"
fi

if [ -n "$CLIP_CMD" ]; then
  echo -e "DB_NAME=$DB_NAME\nDB_USER=$DB_USER\nDB_PASS=$DB_PASS" | $CLIP_CMD
  echo "📋 Info DB telah dicopy ke clipboard!"
else
  echo "⚠️  Clipboard tidak tersedia di server ini."
fi
