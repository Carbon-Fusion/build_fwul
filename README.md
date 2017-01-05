## Build environment/scripts for FWUL 
### ([F]orget [W]indows [U]se [L]inux)

Official XDA thread http://tinyurl.com/FWULatXDA

## Setup & Prepare

1. install **archiso**
1. clone this repo into ~/archlive

## Usage / Build

### 64 bit only

This is the only supported architecture for FWUL because of JOdin

1. `cd ~/archlive`
1. `./build_x64.sh -v -N FWUL_arch_x86_64 -V BETA-XXXX_$(date +%F) -L FWUL`

### Dual ISO's (32 bit + 64 bit)

1. `cd ~/archlive`
1. `./build.sh -v -N FWUL_arch -V BETA-XXXX_$(date +%F) -L FWUL`

## Rebuild / Update ISO

1. `cd ~/archlive`
1. Add the option "-C"  or "-F" option to the instruction in "Usage / Build"
