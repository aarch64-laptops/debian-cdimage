#!/bin/bash

pushd debian/installer/arm64/images/cdrom/
tar xf debian-cd_info.tar.gz
cd grub/
mkdir tmp
mcopy -n -s -i efi.img '::efi' tmp/
mkdir -p tmp/efi/shell
cp ../../../../../../misc/Shell.efi tmp/efi/shell/
rm efi.img
/sbin/mkfs.msdos -v -C efi.img 2048
mcopy -o -s -i efi.img tmp/* "::efi"
rm tmp -rf
cd ../
rm debian-cd_info.tar.gz
tar zcf debian-cd_info.tar.gz grub/
rm grub/ -rf
popd
