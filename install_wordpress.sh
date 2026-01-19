
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
yum install -y httpd php php-mysqlnd php-gd php-xml php-mbstring wget unzip curl jq mysql

systemctl enable httpd
systemctl start httpd

# 2) Préparer le disque EBS (si vierge → mkfs)
if ! file -s ${DEVICE_NAME} | grep -q "filesystem"; then
  mkfs -t xfs ${DEVICE_NAME}
fi

# 3) Monter le volume sur le MOUNT_POINT
mkdir -p ${MOUNT_POINT}
UUID=$(blkid -s UUID -o value ${DEVICE_NAME})
grep -q "$${UUID}" /etc/fstab || echo "UUID=$${UUID} ${MOUNT_POINT} xfs defaults,nofail 0 2" >> /etc/fstab
mount -a

# 4) Installer WordPress sur le volume
cd /tmp
wget -q https://wordpress.org/latest.zip
unzip -q latest.zip
rsync -a /tmp/wordpress/ ${MOUNT_POINT}/
chown -R apache:apache ${MOUNT_POINT}
find ${MOUNT_POINT} -type d -exec chmod 755 {} \;
find ${MOUNT_POINT} -type f -exec chmod 644 {} \;

# 5) Config wp-config.php
cp ${MOUNT_POINT}/wp-config-sample.php ${MOUNT_POINT}/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/" ${MOUNT_POINT}/wp-config.php
sed -i "s/username_here/${DB_USER}/" ${MOUNT_POINT}/wp-config.php
sed -i "s/password_here/${DB_PASS}/" ${MOUNT_POINT}/wp-config.php
sed -i "s/localhost/${DB_HOST}/" ${MOUNT_POINT}/wp-config.php

# 6) Clés SALT
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ || true)
if [ -n "$SALT" ]; then
  sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" ${MOUNT_POINT}/wp-config.php
  echo "$SALT" >> ${MOUNT_POINT}/wp-config.php
fi

systemctl restart httpd

# Healthcheck simple
echo "OK - WordPress déployé, DB: ${DB_HOST}" > /var/www/html/health.txt