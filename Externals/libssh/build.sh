#!/bin/sh

set -e

file=libssh-0.5.3

rm -rf ${file}
tar xf ${file}.tar.gz

if [ -e ${file}.patch ]
then
    patch -p0 < ${file}.patch
fi

rm -rf build
mkdir build
cd build

export MACOSX_DEPLOYMENT_TARGET=10.6

cmake ../${file} -DCMAKE_INSTALL_PREFIX=frameworks -DCMAKE_BUILD_TYPE=MinSizeRel -DCMAKE_C_COMPILER=`xcrun -find -sdk macosx clang` -DCMAKE_OSX_ARCHITECTURES="i386;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -DCMAKE_OSX_SYSROOT=`xcodebuild -version -sdk macosx Path` -DCMAKE_INSTALL_NAME_DIR="@executable_path/../Frameworks" -DWITH_SSH1=ON -DWITH_SERVER=OFF -DWITH_PCAP=OFF

make install

cd ..
rm -rf include
rm -rf lib
mkdir lib
cp -R build/frameworks/include .
cp build/frameworks/lib/libssh.4.dylib lib/
cp build/frameworks/lib/libssh_threads.4.dylib lib/

rm -rf build
rm -rf ${file}
