#!/usr/bin/env python3

import sys
import uuid
from shutil import copyfile

# Generates a CHID (ComputerHardwareID) from key constructed from SMBIOS
# fields
#
# similar to uuid.uuid5() but uses utf-16le (as a stand-in for ucs-2)
# encoding:
def chid(key):
    from hashlib import sha1
    namespace = uuid.UUID('70ffd812-4c7f-4c7d-0000-000000000000')
    hash = sha1(namespace.bytes + bytes(key, "utf-16le")).digest()
    return uuid.UUID(bytes=hash[:16], version=5)

class Dtb(object):
    def __init__(self, dtb, key):
        self.dtb = dtb
        self.chid = chid(key)

# DtbLoader.efi will look for the dtb using the following CHID's in order
# of priority:
#
#   - HardwareID-3:  Manufacturer + Family + ProductName + ProductSku + BaseboardManufacturer + BaseboardProduct
#   - HardwareID-6:  Manufacturer + ProductSku + BaseboardManufacturer + BaseboardProduct
#   - HardwareID-8:  Manufacturer + ProductName + BaseboardManufacturer + BaseboardProduct
#   - HardwareID-10: Manufacturer + Family + BaseboardManufacturer + BaseboardProduct
#   - HardwareID-4:  Manufacturer + Family + ProductName + ProductSku
#   - HardwareID-5:  Manufacturer + Family + ProductName
#   - HardwareID-7:  Manufacturer + ProductSku
#   - HardwareID-9:  Manufacturer + ProductName
#   - HardwareID-11: Manufacturer + Family
#
# HardwareID-9 should be appropriate in most cases.
#
# The different SMBIOS fields have leading/trailing whitespace stripped,
# and leading zero's skipped, and are separated by "&".  This matches how
# fwupd calculates CHIDs/HWIDs, which seems to match what windows
# (ComputerHardwareIds.exe) does.
#
# See https://blogs.gnome.org/hughsie/2017/04/25/reverse-engineering-computerhardwareids-exe-with-winedbg/
dtbs = [
    # Lenovo c630:
    Dtb('qcom/sdm850-lenovo-yoga-c630.dtb', 'LENOVO&81JL'),   # Manufacturer&ProductName => 'HardwareID-9'
    # At least one c630 in the wild has 'INVALID' for the product name, so lets also try 'Family'
    Dtb('qcom/sdm850-lenovo-yoga-c630.dtb', 'LENOVO&Yoga C630-13Q50 Laptop'),  # Manufacturer&Family => 'HardwareID-11'
    # Lenovo flex5g:
    Dtb('qcom/sc8180x-lenovo-flex-5g.dtb',  'LENOVO&82AK'),   # Manufacturer&ProductName => 'HardwareID-9'
]

src = sys.argv[1]
dst = sys.argv[2]

for dtb in dtbs:
    print(src + "/" + dtb.dtb + " => " + dst + "/" + str(dtb.chid) + ".dtb")
    copyfile(src + "/" + dtb.dtb, dst + "/" + str(dtb.chid) + ".dtb")

