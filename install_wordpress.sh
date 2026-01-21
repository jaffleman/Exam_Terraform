
#!/bin/bash
set -euxo pipefail

DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"
DB_HOST="${DB_HOST}"
MOUNT_POINT="${MOUNT_POINT}"
DEVICE_NAME="${DEVICE_NAME}"

# 0) Attendre que le device EBS apparaisse (jusqu'à ~60s)
for i in {1..30}; do
  if [ -b "${DEVICE_NAME}" ]; then
    echo "Device ${DEVICE_NAME} disponible."
    break
  fi
  echo "Attente du device ${DEVICE_NAME} ..."
  sleep 2
done

# 1) MAJ + LAMP + utilitaires
yum update -y
amazon-linux-extras enable php8.2 || true
yum install -y httpd php php-mysqlnd php-gd php-xml php-mbstring php-json php-curl php-zip wget unzip curl jq mysql rsync

systemctl enable httpd
systemctl start httpd

# 2) Préparer le disque EBS (si vierge → mkfs)
if ! file -s "${DEVICE_NAME}" | grep -q "filesystem"; then
  mkfs -t xfs "${DEVICE_NAME}"
fi

# 3) Monter le volume sur le MOUNT_POINT
mkdir -p "${MOUNT_POINT}"
UUID=$(blkid -s UUID -o value "${DEVICE_NAME}")
# IMPORTANT : $$ pour échapper Terraform ; le user_data final contiendra $${UUID} (évalué par bash)
if ! grep -q "$${UUID}" /etc/fstab; then
  echo "UUID=$${UUID} ${MOUNT_POINT} xfs defaults,nofail 0 2" >> /etc/fstab
fi
mount -a

# 4) Installer WordPress sur le volume
cd /tmp
wget -q https://wordpress.org/latest.zip
unzip -q -o latest.zip
rsync -a /tmp/wordpress/ "${MOUNT_POINT}/"

# 5) Config wp-config.php (création)
cp "${MOUNT_POINT}/wp-config-sample.php" "${MOUNT_POINT}/wp-config.php"
# Remplacements DB
sed -i "s/database_name_here/${DB_NAME}/" "${MOUNT_POINT}/wp-config.php"
sed -i "s/username_here/${DB_USER}/" "${MOUNT_POINT}/wp-config.php"
# Mot de passe : protéger / et & pour sed
ESC_PASS=$(printf '%s\n' "${DB_PASS}" | sed -e 's/[\/&]/\\&/g')
sed -i "s/password_here/$${ESC_PASS}/" "${MOUNT_POINT}/wp-config.php"
sed -i "s/localhost/${DB_HOST}/" "${MOUNT_POINT}/wp-config.php"

# 6) Clés SALT : insérer AVANT la ligne "That's all, stop editing"
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ || true)
if [ -n "$${SALT}" ]; then
  awk -v SALT="$${SALT}" '
    /\/\* That'\''s all, stop editing/ && !done {
      print SALT
      done=1
    }
    # Supprimer éventuelles lignes SALT existantes
    !/AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT/ { print }
  ' "${MOUNT_POINT}/wp-config.php" > "${MOUNT_POINT}/wp-config.php.new"
  mv "${MOUNT_POINT}/wp-config.php.new" "${MOUNT_POINT}/wp-config.php"
fi

# 7) Propriété/permissions APRÈS la création de wp-config.php
chown -R apache:apache "${MOUNT_POINT}"
find "${MOUNT_POINT}" -type d -exec chmod 755 {} \;
find "${MOUNT_POINT}" -type f -exec chmod 644 {} \;

# 8) Si MOUNT_POINT != /var/www/html : basculer DocumentRoot via symlink
if [ "${MOUNT_POINT}" != "/var/www/html" ]; then
  rm -rf /var/www/html
  ln -s "${MOUNT_POINT}" /var/www/html
fi

systemctl restart httpd
systemctl restart php-fpm 2>/dev/null || true

# Healthcheck simple
echo "OK - WordPress déployé, DB: ${DB_HOST}" > /var/www/html/health.txt
