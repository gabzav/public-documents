cat > .devcontainer/postCreate.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/public-documents

echo "== Sanity: GD loaded? =="
php -m | grep -i gd

echo "== Install Drupal (if missing) =="
if [ ! -d web/core ] && [ ! -d drupal-temp/web/core ]; then
  composer create-project drupal/recommended-project:^11 drupal-temp --no-interaction
fi

# Move into repo root if still in drupal-temp
if [ -d drupal-temp/web/core ] && [ ! -d web/core ]; then
  shopt -s dotglob
  mv drupal-temp/* .
  rmdir drupal-temp
fi

echo "== Apache docroot -> /workspaces/public-documents/web =="
sed -i 's#DocumentRoot /var/www/html#DocumentRoot /workspaces/public-documents/web#g' /etc/apache2/sites-available/000-default.conf

# Ensure AllowOverride for Drupal .htaccess
if ! grep -q "/workspaces/public-documents/web" /etc/apache2/apache2.conf; then
  cat >> /etc/apache2/apache2.conf <<'CONF'

<Directory /workspaces/public-documents/web/>
  AllowOverride All
  Require all granted
</Directory>
CONF
fi

echo "== Prepare sites/default =="
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

service apache2 restart

echo ""
echo "✅ Ready. Open port 8080 -> /core/install.php"
echo "Use SQLite in the installer (no DB server needed)."
BASH

chmod +x .devcontainer/postCreate.sh
