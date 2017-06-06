## Build environment/scripts for FWUL 
### ([F]orget [W]indows [U]se [L]inux)

Official XDA thread http://tinyurl.com/FWULatXDA

## Setup & Prepare (Arch Linux)

No other distribution then Arch Linux is supported (for both: build system and FWUL release).

1. install **archiso**
1. git clone https://github.com/Carbon-Fusion/build_fwul.git ~/build_fwul


## Usage / Build

### 64 bit (recommended)

This is the only full supported architecture for FWUL! 
There is a i686 / 32 bit version of FWUL available but this may change in the
future plus: it may be abandoned one day!

1. `cd ~/build_fwul`
1. `sudo ./build_x64.sh -A x86_64 -F`

Use `./build_x64.sh --help` to find all possible options like working directory etc.
You can also specify a single run with multiple architectures `-A 'i686 x86_64'`.


### 32 bit (not fully supported)

i686 / 32 bit builds are NOT fully supported and tools may be missing here
completely! One example (just one!): 32bit will NOT INCLUDE JOdin.

The support for 32bit may be abandoned one day! For the background 
please read: https://www.archlinux.org/news/phasing-out-i686-support

Note: You can build a 32 bit version of FWUL on a 64 bit system.

1. `cd ~/build_fwul`
1. `sudo ./build_x64.sh -A i686 -F`

Use `./build_x64.sh --help` to find all possible options like working directory etc.
You can also specify a single run with multiple architectures `-A 'i686 x86_64'`.


## Rebuild / Update ISO

1. `cd ~/build_fwul`
1. Add the option "-C"  or "-F" option to the instruction in "Usage / Build"
