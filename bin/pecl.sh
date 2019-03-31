echo "Downloading PECL"
curl -O https://pear.php.net/go-pear.phar

echo "Installing PECL"
php -d detect_unicode=0 go-pear.phar