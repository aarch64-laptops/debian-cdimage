# Debian CD Image for AArch64 Laptops

The repository contains the Debian CD image releases for AArch64
Laptops.  The CD image works on AArch64 laptops in the same way as what
people usually see on X86 devices.  This guide takes Lenovo Yoga C630 as
the target and only documents the quirks we need to deal with on AArch64
laptops.  The assumption is that the laptop has a Windows 10 installed
there.

## Installer limitations

After installation completes, you will get a fully functional kernel
booting with device tree.  But installer kernel boots up with ACPI and
only provides a minimal support required by installation, like display
via efifb, HID devices, USB and UFS.  Here are a few non-working
items you may want to know.

* Currently only left side USB port works.  That means you have to boot
  USB disk containing the CD image from left hand USB port.  We will
  enable the other USB port soon.

* Wifi is not working for installer.  While USB dongle could be used to
  get network support in installer, this guide assumes there is no
  network connection with the installation.

* There are two options to run installer that you can choose from Grub
  menu: `Install` and `Graphic install`.  The first option provides
  a text based installer interface, where only keyboard could be used.
  The second gives a graphic interface, where you can use touch screen
  and mouse in additional.  However, the mouse cursor movement via touch
  pad is not working right now.  We will fix it.

## Installation tips

Although the installation is intuitive and Debian install guide could be found [here](https://www.debian.org/releases/stable/installmanual),
we would like to give a few tips you might find them useful.

* The installer is able to resize Windows partition, so that disk space
  could be freed up for Debian installation.  Go for `Manual` option at
  `Partition disks` step, set up partitions for Debian installation.
  After all changes are made, scroll down the screen to select
  `Finish partitioning and write changs to disk`.

* As there is no network connection during the installation, `Configure
  the package manager` step should be skipped by selecting `Go Back`
  instead of `Continue`.

* The step 'Install the GRUB boot loader' takes a couple of minutes to
  complete.  Be patient.

## AArch64 quirks

If everything goes fine, you will get `Installation complete` prompt in
the end.  However, it's not really completed yet for AArch64 devices, as
we need to run UEFI Shell.efi for a couple of reasons.

* Linux efibootmgr utility doesn't work on AArch64 devices.  Consequently
  UEFI Boot variable cannot be modified to point to Grub, and device
  still directly boots into Windows.  You can choose to use Windows command
  prompt to change the variable.  But that doesn't work for Windows S mode
  where command prompt is not available at all.  So we suggest to use
  Shell.efi here.

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
   is a grubaa64.efi in `EFI\debian` folder.

```
Shell> map -r -b
Shell> fs5:
FS5:\> ls EFI\debian
```

4. Modify variable `Boot0001` to get it point to grubaa64.efi.  The number
   `2` in the second command is identified by looking at `Option` filed in
   the first command output.

```
FS5:\> bcfg boot dump
...
Option 02. Variable: Boot0001
  Desc   - Windows Boot Manager
...
FS5:\> bcfg boot modf 2 EFI\debian/grubaa64.efi
```

5. Tell UEFI to launch DtbLoader.efi for every boot.

```
FS5:\> bcfg driver add 1 DtbLoader.efi "dtb loader"
```
6. Now installation really completes.  Remove the USB disk and reboot
   like below.

```
FS5:\> reset
```

## Debian first-run

At this point, you should be able to boot up Debian and login Gnome
desktop.  Here are a few things that you want to set up to get the best
experience.

1. Go to Settings and set up Wi-Fi to get a network connection.

2. Add user to sudo group.

```
$ su - root
$ usermod -aG sudo <username>
$ exit
$ su - <username>
```

3. Update /etc/apt/sources.list with the best Debian mirror per your
   location, drop sid-security repository which doesn't have a Release
   file.

```
$ cat /etc/apt/sources.list
deb http://ftp.us.debian.org/debian sid main
deb-src http://ftp.us.debian.org/debian sid main
$ sudo apt update
```

4. Install alsa-ucm-conf from Linaro OBS to enable audio.

```
$ sudo apt install alsa-ucm-conf=1.2.3-1+linaro3
$ pulseaudio -k
$ pulseaudio --start
```
