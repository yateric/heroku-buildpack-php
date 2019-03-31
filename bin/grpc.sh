echo "Installing grpc extension"
git clone -b $(curl -L https://grpc.io/release) https://github.com/grpc/grpc

cd grpc
git pull --recurse-submodules && git submodule update --init --recursive
make
sudo make install

cd src/php/ext/grpc
phpize
./configure
make
sudo make install