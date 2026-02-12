cat > .devcontainer/postCreate.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/workspaces/public-documents"

echo "== System deps =="
sudo apt-get update
sudo apt-get install -y mariadb-server \
  libpng-dev libjpeg-dev libfreetype6-dev \
  libzip-dev libicu-dev unzip curl

echo "== PHP extensions for Drupal =="
sudo docker-php-ext-configure gd --with-freetype --with-jpeg
sudo docker-php-ext-install gd zip intl

echo "== Start MariaDB =="
sudo service mysql start

echo "== DB setup (idempotent) =="
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS drupal;
CREATE USER IF NOT EXISTS 'drupal'@'localhost' IDENTIFIED BY 'drupal';
GRANT ALL PRIVILEGES ON drupal.* TO 'drupal'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "== Composer =="
if ! command -v composer >/dev/null 2>&1; then
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/local/bin/composer
fi

cd "$REPO_DIR"

echo "== Drupal codebase (recommended-project) =="
if [ ! -d "$REPO_DIR/web/core" ]; then
  # If repo is empty, create Drupal in-place.
  if [ ! -f "$REPO_DIR/composer.json" ]; then
    composer create-project drupal/recommended-project:^11 . --no-interaction
  else
    composer install --no-interaction
  fi
fi

echo "== settings.php + files dir =="
mkdir -p web/sites/default/files
if [ ! -f web/sites/default/settings.php ]; then
  cp web/sites/default/default.settings.php web/sites/default/settings.php
fi
chmod 666 web/sites/default/settings.php || true
chmod -R 777 web/sites/default/files || true

echo "== Codespaces proxy/host support =="
if ! grep -q "app\\.github\\.dev" web/sites/default/settings.php; then
  cat >> web/sites/default/settings.php <<'PHP'

$settings['trusted_host_patterns'] = [
  '^localhost$',
  '^127\.0\.0\.1$',
  '^.*\.app\.github\.dev$',
];

$settings['reverse_proxy'] = TRUE;
$settings['reverse_proxy_trusted_headers'] = \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_ALL;
PHP
fi

echo "== Apache docroot -> /workspaces/public-documents/web =="
sudo sed -i 's#DocumentRoot /var/www/html#DocumentRoot /workspaces/public-documents/web#g' /etc/apache2/sites-available/000-default.conf
# Ensure directory permissions match docroot
if ! grep -q "/workspaces/public-documents/web" /etc/apache2/apache2.conf; then
  # Add a directory block if missing
  cat | sudo tee -a /etc/apache2/apache2.conf >/dev/null <<'CONF'

<Directory /workspaces/public-documents/web/>
  AllowOverride All
  Require all granted
</Directory>
CONF
fi

sudo a2enmod rewrite headers >/dev/null 2>&1 || true
sudo service apache2 restart

echo ""
echo "✅ Ready."
echo "Open port 8080 in the Ports tab."
echo "Installer: /core/install.php"
echo "DB: host=localhost db=drupal user=drupal pass=drupal"
BASH

chmod +x .devcontainer/postCreate.sh
