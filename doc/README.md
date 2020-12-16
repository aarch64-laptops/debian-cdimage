# Debian CD Image Build Instructions

The build of Debian CD Image released in this repository involves the
following steps.

* [Build kernel debs](#build-kernel-debs)
* [Build debian-installer kernel module udebs](#build-debian-installer-kernel-module-udebs)
* [Build debian-installer](#build-debian-installer)
* [Build CD image](#build-cd-image)

The first step can be done on x86/amd64 system with cross-compile.  The
rest should be natively done on arm64 Debian Sid system.  Docker container
would be a good choice, and the steps documented here are tested on Debian
Sid docker container.  Let's explore each of the steps in details.


## Build kernel debs

There are two kernels to be built.  One is what installer itself runs on,
and we call it `Installer kernel` in this document.  The other is what
the installation attempts to install, and we call it `Debian kernel`.
Although these two kernels can be the same one, we choose to use different
ones for the CD Image we build here.  Installer Kernel will boot using ACPI
with limited support required by installation, like display via efifb,
HID devices, USB and UFS.  And the installation kernel will boot using DT
with full features.

* Build Installer kernel deb.  It can be native or cross-compile build.
  To get a faster build, we choose cross-compile build here.  After the
  build completes, `linux-image-5.10.0-custom_5.10.0-custom-1_arm64.deb`
  should be available in the parent directory, and it will be used later
  for building debian-installer kernel module udebs.

```
$ git checkout https://github.com/aarch64-laptops/linux.git
$ cd linux/
$ git checkout -b laptops-5.10 origin/laptops-5.10
$ export CROSS_COMPILE=aarch64-none-linux-gnu-
$ make ARCH=arm64 distro_defconfig
$ make ARCH=arm64 LOCALVERSION="-custom" -j15 deb-pkg
```

* Build Debian kernel deb.  The build commands are same as above with
  different branch checked out.  Also, to clean up the previous build,
  a `make mrproper` is required before the building.  After the build
  completes, `linux-image-5.10.0-rc5-next-20201127-custom_5.10.0-rc5-next-20201127-custom-1_arm64.deb`
  should be available in the parent directory.  A copy of the package has
  been checked into `simple-cdd/localpackages/` for CD image build.

```
$ git checkout -b laptops-next-20201127 origin/laptops-next-20201127
$ make mrproper
$ make ARCH=arm64 distro_defconfig
$ make ARCH=arm64 LOCALVERSION="-custom" -j15 deb-pkg
```


## Build debian-installer kernel module udebs

[kernel-wedge](https://salsa.debian.org/installer-team/kernel-wedge) is used
to generate kernel module udebs for debian-installer.

* Install kernel-wedge.

```
$ sudo apt install kernel-wedge
```

* Clone debian-cdimage repository and go to `linux-kernel-di-arm64`
  directory.  The `linux-kernel-di-arm64` is a debian source package that
  is manually created for building kernel module udebs for debian-installer.
  The `modules` folder and `package-list` file are copied from
  [debian kernel tree](https://salsa.debian.org/kernel-team/linux) with
  desired tag.

```
$ cd $HOME
$ git clone https://github.com/aarch64-laptops/debian-cdimage.git
$ cd debian-cdimage/kernel-wedge/linux-kernel-di-arm64/
```

* Install the installer kernel deb.  The kernel-wedge requires the installer
  kernel package be installed on the system to build kernel module udebs.

```
$ sudo dpkg -i <path_to_file>/linux-image-5.10.0-custom_5.10.0-custom-1_arm64.deb
```

* Generate `debian/control` and start the build.  After build completes,
  a bunch of .udeb files will be found in the parent folder.

```
$ export KW_DEFCONFIG_DIR=$PWD
$ kernel-wedge gen-control > debian/control
$ kernel-wedge build-arch arm64
```


## Build debian-installer

The steps documented here are basically collected from debian-installer
[WIKI](https://wiki.debian.org/DebianInstaller/Build) page and 
[README](https://salsa.debian.org/installer-team/debian-installer/-/tree/master/build).

* Check out debian-installer source and install build dependencies.

```
$ sudo apt install myrepos
$ cd ~/debian-cdimage/
$ git clone https://salsa.debian.org/installer-team/d-i.git debian-installer
$ cd debian-installer
$ scripts/git-setup
$ mr checkout
$ sudo apt build-dep debian-installer
```

* The grub-installer package from `sid main/debian-installer` repository
  doesn't work for AArch64 laptops, because EFI variables runtime service
  is not available on the devices. We need to apply a patch and regenerate
  the package for CD image build.  A copy of the package has been checked
  into `simple-cdd/localpackages/`.  So the last `cp` command is only for
  documentation purpose here.

```
$ cd packages/grub-installer/
$ git am ../../../patches/debian-installer/grub-installer/0001-grub-installer-no-nvram-for-arm64.patch
$ sudo apt build-dep grub-installer
$ dpkg-buildpackage -b
$ cd ../
$ cp grub-installer_1.173_arm64.udeb ../../simple-cdd/localpackages/
```

* The os-prober package from `sid main/debian-installer` repository doesn't
  probe Windows OS.  We need to apply a patch and regenerate the deb and udeb
  for CD image build.  A copy of the packages have been checked into
  `simple-cdd/localpackages/`.  So the last `cp` command is only for
  documentation purpose here.

```
$ cd os-prober/
$ git am ../../../patches/debian-installer/os-prober/0001-os-probes-probe-microsoft-OS-on-arm64.patch
$ dpkg-buildpackage -b
$ cd ../
$ cp os-prober-udeb_1.78_arm64.udeb os-prober_1.78_arm64.deb ../../simple-cdd/localpackages/
```

* Prepare localudebs for debian-installer build.  The kernel module udebs
  generated by kernel-wedge are copied here in this step.

```
$ cd ../../installer/build/
$ cp ~/debian-cdimage/kernel-wedge/*.udeb localudebs/
$ echo "deb http://deb.debian.org/debian sid main/debian-installer" >> sources.list.udeb.local
$ echo "deb [trusted=yes] copy:$HOME/debian-cdimage/debian-installer/installer/build localudebs/" >> sources.list.udeb.local
```

* Modify config/arm64.cfg to customize local version string for
  differentiating from official Debian image, and disable Secure Boot build.

```
$ sed -i "s/-arm64/-custom/g" config/arm64.cfg
$ sed -i "s/EFI_SIGNED=y/#EFI_SIGNED=y/g" config/arm64.cfg
```

* Build debian-installer.  The build result will be found in `dest` folder.

```
$ make LINUX_KERNEL_ABI=5.10.0 build_cdrom_grub
$ make LINUX_KERNEL_ABI=5.10.0 build_cdrom_gtk
```


## Build CD Image

[Simple-CDD](https://wiki.debian.org/Simple-CDD) is used to build Debian
CD image here.

* Install simple-cdd and apply patches.

```
$ sudo apt install simple-cdd
$ cd /usr/share/simple-cdd
$ sudo patch -p1 < ~/debian-cdimage/patches/simple-cdd/0001-Fix-resolution-of-virtual-packages-by-reprepro-mirro.patch
$ sudo patch -p1 < ~/debian-cdimage/patches/simple-cdd/0002-Update-default.preseed-for-aarch64-laptops-build.patch
```

* Copy installer.

```
$ cd ~/debian-cdimage/simple-cdd/
$ mkdir -p debian/installer/arm64/images/
$ cp -a ../debian-installer/installer/build/dest/* debian/installer/arm64/images/
```

* Pack Shell.efi into efi.img.

```
$ ./misc/pack_shell_efi.sh
```

* Copy udebs to localpackages.

```
$ cp ../kernel-wedge/*.udeb localpackages/
```

* Update profiles/gnome.conf.

```
$ echo "local_packages=\"$PWD/localpackages\"" >> profiles/gnome.conf
$ echo "custom_installer=\"$PWD/debian/installer\"" >> profiles/gnome.conf
```

* Build CD image.  If everything goes fine, the result CD image should be
  found as `images/debian-unstable-arm64-DVD-1.iso`.

```
$ build-simple-cdd --dvd --profiles gnome
```
