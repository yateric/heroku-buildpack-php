echo "Installing protobuf extension"
/app/.heroku/php-min/bin/pecl install protobuf

echo "Importing protobuf extension to php.ini"
echo "extension=protobuf.so" >> /app/.heroku/php/etc/php/php.ini
