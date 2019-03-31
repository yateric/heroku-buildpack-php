echo "Installing grpc extension"
pecl install grpc

echo "Importing grpc extension to php.ini"
echo "extension=grpc.so" >> /app/.heroku/php/etc/php/php.ini
