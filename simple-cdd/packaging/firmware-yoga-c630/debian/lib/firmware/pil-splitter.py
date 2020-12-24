#! /usr/bin/env python
"""
Splits elf files into segments.

If the elf is signed, the elf headers and the hash segment are output to
the *.mdt file, and then the segments are output to *.b<n> files.

If the elf isn't signed each segment is output to a *.b<n> file and the
elf headers are output to the *.mdt file.
"""

import sys
import struct

def die(message):
  print message
  exit(1)

def usage():
  print "Usage: %s <elf> <prefix>" % sys.argv[0]
  exit(1)

def dump_data(input, output, start, size):
  """Dump 'size' bytes from 'input' at 'start' into newfile 'output'"""

  if size == 0:
    return

  input.seek(start)
  outFile = open(output, 'wb')
  outFile.write(input.read(size))
  outFile.close()

  print 'BIN %s' % output

def append_data(input, output, start, size):
  """Append 'size' bytes from 'input' at 'start' to 'output' file"""

  if size == 0:
    return

  input.seek(start)
  outFile = open(output, 'ab')
  outFile.write(input.read(size))
  outFile.close()

def gen_struct(format, image):
  """Generates a dictionary from the format tuple by reading image"""

  str = "<%s" % "".join([x[1] for x in format])
  elems = struct.unpack(str, image.read(struct.calcsize(str)))
  keys = [x[0] for x in format]
  return dict(zip(keys, elems))

def parse_metadata(image):
  """Parses elf header metadata"""
  metadata = {}

  elf32_hdr = [
      ("ident", "16s"),
      ("type", "H"),
      ("machine", "H"),
      ("version", "I"),
      ("entry", "I"),
      ("phoff", "I"),
      ("shoff", "I"),
      ("flags", "I"),
      ("ehsize", "H"),
      ("phentsize", "H"),
      ("phnum", "H"),
      ("shentsize", "H"),
      ("shnum", "H"),
      ("shstrndx", "H"),
      ]
  elf32_hdr = gen_struct(elf32_hdr, image)
  metadata['num_segments'] = elf32_hdr['phnum']
  metadata['pg_start'] = elf32_hdr['phoff']

  elf32_phdr = [
      ("type", "I"),
      ("offset", "I"),
      ("vaddr", "I"),
      ("paddr", "I"),
      ("filesz", "I"),
      ("memsz", "I"),
      ("flags", "I"),
      ("align", "I"),
      ]

  print "pg_start = 0x%08x" % metadata['pg_start']

  metadata['segments'] = []  
  for i in xrange(metadata['num_segments']):
    poff = metadata['pg_start'] + (i * elf32_hdr['phentsize'])
    image.seek(poff)
    phdr = gen_struct(elf32_phdr, image)
    metadata['segments'].append(phdr)
    phdr['hash'] = (phdr['flags'] & (0x7 << 24)) == (0x2 << 24)
    print "["+str(i)+"] %08x" % poff," offset =",phdr['offset']," size =",phdr['filesz']

  return metadata

def dump_metadata(metadata, image, name):
  """Creates <name>.mdt file from elf metadata"""

  name = "%s.mdt" % name
  # Dump out the elf header
  dump_data(image, name, 0, 52)
  # Append the program headers
  append_data(image, name, metadata['pg_start'], 32 * metadata['num_segments'])

  for seg in metadata['segments']:
    if seg['hash']:
      append_data(image, name, seg['offset'], seg['filesz'])
      break

def dump_segments(metadata, image, name):
  """Creates <name>.bXX files for each segment"""
  for i, seg in enumerate(metadata['segments']):
    start = seg['offset']
    size = seg['filesz']
    output = "%s.b%02d" % (name, i)
    dump_data(image, output, start, size)

def is_elf(file):
  """Verifies a file as being an ELF file"""
  file.seek(0)
  magic = file.read(4)
  image.seek(0)
  return magic == '\x7fELF'

if __name__ == "__main__":

  if len(sys.argv) != 3:
    usage()

  image = open(sys.argv[1], 'rb')
  if not is_elf(image):
    usage()

  prefix = sys.argv[2]
  metadata = parse_metadata(image)
  dump_metadata(metadata, image, prefix)
  dump_segments(metadata, image, prefix)
