# Debian CD Image for AArch64 Laptops

The repository contains the Debian CD image [releases](https://github.com/aarch64-laptops/debian-cdimage/releases) for AArch64
Laptops.  The CD image works on AArch64 laptops in the same way as what
people usually see on x86 devices.  This guide only highlights the quirks
we need to deal with on AArch64 laptops.  The CD image is tested on Lenovo
Yoga C630 and Flex 5G laptops with the following conditions.

* [Secure Boot](https://github.com/aarch64-laptops/build#disabling-secure-boot-on-the-lenovo-c630) is disabled.
* The laptop has Windows 10 installed.
* [BitLocker](https://www.m3datarecovery.com/bitlocker-windows-home/turn-off-bitlocker-windows10.html) on Windows partition is turned off.

## Installer limitations

After installation completes, you will get a fully functional kernel
booting with device tree.  But installer kernel boots up with ACPI and
only provides a minimal support required by installation, like display
via efifb, HID devices, USB and UFS.

* Wifi is not working for installer.  While USB dongle could be used to
  get network support in installer, this guide assumes there is no
  network connection with the installation.

## Installation tips

Although the installation is intuitive and Debian install guide could be found
[here](https://www.debian.org/releases/stable/installmanual),
we would like to give a few tips you might find them useful.

* The installer is able to resize Windows partition, so that disk space
  could be freed up for Debian installation.  Go for `Manual` option at
  `Partition disks` step, set up partitions for Debian installation.
  After all changes are made, scroll down the screen to select
  `Finish partitioning and write changes to disk`.

* As there is no network connection during the installation, `Configure
  the package manager` step should be skipped by selecting `Go Back`
  instead of `Continue`.

* The step `Install the GRUB boot loader` takes quite a while to
  complete.  Be patient.

## AArch64 quirks

If everything goes fine, you will get `Installation complete` prompt in
the end.  However, it's not really completed yet for AArch64 devices, as
we need to run UEFI Shell.efi for a couple of reasons.

* Linux efibootmgr utility doesn't work on AArch64 devices, because efivars
  doesn't work.  The reason behind it is that EFI variables are stored on
  UFS, while firmware and OS cannot share the UFS device.  Consequently
  EFI Boot variable cannot be modified to point to Grub, and device always
  directly boots into Windows.  We need to use Shell.efi for EFI variable
  update.

* [DtbLoader](https://github.com/robclark/edk2/tree/dtbloader-chid) is
  used to load DTB using CHIDs.  DtbLoader.elf and DTBs named in CHIDs
  have been installed to ESP partition as part of the Debian
  installation.  But we need to additionally insert a command to UEFI,
  so that DtbLoader.efi will be run by UEFI for every power-on.

Follow the steps below to launch Shell.efi for completing installation.

1. From Debian `Installation complete` prompt, reboot with leaving USB
   disk plugged-in.  Press 'c' in Grub menu to get 'grub> '
   command-line prompt.

2. Launch Shell.efi that resides in USB disk like below.

```
grub> chainloader (hd0,msdos2)/efi/shell/Shell.efi
grub> boot
```

3. Identify the FS number of ESP partition on UFS by checking there
   is a grubaa64.efi in `EFI\debian` folder.  For example, it's `fs5:`
   on Lenovo Yoga C630 and `fs4:` on Flex 5G.

```
Shell> map -r -b
Shell> fs5:
FS5:\> ls EFI\debian
```

4. Modify variable `Boot0001` to get it point to grubaa64.efi.  The number
   `2` in the second command is identified by looking at `Option` field in
   the first command output.

```
FS5:\> bcfg boot dump
...
Option 02. Variable: Boot0001
  Desc   - Windows Boot Manager
...
FS5:\> bcfg boot modf 2 EFI\debian\grubaa64.efi
```

**Note:** In case there is no Boot option, for example on the fresh Flex 5G system,
use the following command to add an option for grubaa64.efi.

```
FS4:\> bcfg boot dump
No options found.
FS4:\> bcfg boot add 0 EFI\debian\grubaa64.efi "GRUB"
```

5. Tell UEFI to launch DtbLoader.efi for every boot.

```
FS5:\> bcfg driver add 1 DtbLoader.efi "dtb loader"
```

**Note:** This step is not needed for Flex 5G, because the firmware on the
laptop doesn't support driver loading.  And we use GRUB `devicetree`
command to load DTB on Flex 5G.

6. Now installation really completes.  Remove the USB disk and reboot
   like below.

```
FS5:\> reset
```

## Firmware installation

At this point, you should be able to boot up and login Debian system.
However, some hardware blocks are not working properly yet
because firmware is missing.  Follow steps below to install firmware.

1. Add user to sudo group.

```
$ su - root
$ usermod -aG sudo <username>
$ exit
$ su - <username>
```

2. Run firmware extract script to retrieve firmware files that we cannot find
   in linux-firmware repository from Windows partition. This is a cut-down
   version of a script from the [Celliwig](https://github.com/Celliwig/Lenovo-Yoga-c630)
   project.

* Lenovo Yoga C630
```
$ /lib/firmware/yoga_fw_extract.sh
```

* Lenovo Flex 5G
```
$ /lib/firmware/flex5g_fw_extract.sh
```

3. Reboot the device.


## Debian first-run

Here are a few things that you want to set up to get the best experience.

### Lenovo Yoga C630

1. Go to Settings and set up Wi-Fi to get a network connection.

2. Update /etc/apt/sources.list with the best Debian mirror per your
   location, drop sid-security repository which doesn't have a Release
   file.

```
$ cat /etc/apt/sources.list
deb http://deb.debian.org/debian sid main
deb-src http://deb.debian.org/debian sid main
$ sudo apt update
```

3. Install alsa-ucm-conf from Linaro OBS to enable audio.

```
$ sudo apt install alsa-ucm-conf
$ pulseaudio -k
```

### Lenovo Flex 5G

The support of Lenovo Flex 5G is half-baked at this point. The graphic
support is not available yet. Follow the example below to setup WiFi
with command-line.

```
nmcli con add con-name WiFi ifname wlan0 type wifi ssid <Your_Network_SSID>
nmcli con modify WiFi wifi-sec.key-mgmt wpa-psk
nmcli con modify WiFi wifi-sec.psk <Your_WiFi_Password>
nmcli con up WiFi
```

## Misc tips

* The default GNOME login is backed by Wayland. If you want to use login
  backed by Xorg like `System X11 Default`, `GNOME Classic` or
  `GNOME on Xorg`, package `xinit` needs to be installed.

```
$ sudo apt install xinit
```

* By default, only left button on touchpad works.  Goto
  `Settings -> Mouse & Touchpad -> Touchpad` and turn on option
  `Tap to Click`, so that you will get one-finger tap as left click and
  two-fingers tap as right click.
