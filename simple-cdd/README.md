# Notes about simple-cdd build

## Important fix

The simple-cdd release for Sid misses the fix for [Bug 949255]
(https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=949255).

## Local binary packaging
```
$ cd simple-cdd/packaging/firmware-yoga-c630/
$ sudo chown -R root:root debian
$ dpkg-deb --build debian
$ mv debian.deb firmware-yoga-c630_0.1-1_arm64.deb
```

## Linaro OBS
```
$ cat /etc/apt/sources.list.d/linaro.list 
deb http://obs.linaro.org/linaro-overlay-sid/sid/ ./
deb-src http://obs.linaro.org/linaro-overlay-sid/sid/ ./
$ sudo wget -O /etc/apt/trusted.gpg.d/linaro.asc http://obs.linaro.org/linaro-overlay-sid/sid/Release.key
$ sudo apt update
$ apt download pd-mapper qrtr libqrtr1 rmtfs tqftpserv fastrpc
```

## Remove package from simple-cdd mirror

To update a package in the simple-cdd mirror, just remove it with
`reprepro` command, and the next `build-simple-cdd` will update the
mirror with new package.

```
$ reprepro --help
$ cd tmp/mirror/
$ reprepro remove sid firmware-yoga-c630
```
