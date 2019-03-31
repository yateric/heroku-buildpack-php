echo "Installing grpc extension"
/app/.heroku/php-min/bin/pecl install grpc

echo "Importing grpc extension to php.ini"
echo "extension=grpc.so" >> /app/.heroku/php/etc/php/php.ini
