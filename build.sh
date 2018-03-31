#!/bin/sh

set -x

##
# use the arm-none-eabi toolchain;
# targets for ARM architecture, has no vendor,
# does not target an operating system and complies with the ARM Embedded ABI
#

{
gnuarmet="arm-none-eabi"
sourcefname=""
modulename=""
} 2> /dev/null

for sfile in ./src/*.s
do
  {
  sourcefname=$(basename "$sfile")
  modulename="${sourcefname%.*}"
  } 2> /dev/null
  $gnuarmet-as -march=armv6 -I src/ src/$sourcefname -o obj/$modulename.o
done

$gnuarmet-ld --no-undefined obj/*.o -L./lib -l csud -Map ./dist/kernel.map -o obj/output.elf -T kernel.ld
$gnuarmet-objcopy obj/output.elf -O binary ./dist/kernel.img
$gnuarmet-objdump -d obj/output.elf > ./dist/kernel.list
