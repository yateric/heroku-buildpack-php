echo "Install protobuf extension"
pecl install protobuf

echo "Import protobuf extension to php.ini"
echo "extension=protobuf.so" >> /app/.heroku/php/etc/php/php.ini
