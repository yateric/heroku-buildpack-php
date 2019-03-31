echo "Install grpc extension"
pecl install grpc

echo "Import grpc extension to php.ini"
echo "extension=grpc.so" >> /app/.heroku/php/etc/php/php.ini
