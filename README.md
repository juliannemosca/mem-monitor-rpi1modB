Memory monitor for the RPi 1, Model B

# Memory Monitor for the Raspberry Pi 1 Model B

A very simple memory monitor written in ARM assembly language. Very much inspired by Wozniak's 1976 original memory monitor for the Apple 1 (WOZ Monitor), it even uses the same font for that extra retro feel. :)

## Usage

There are 3 types of operations available, with different input options, those are Read, Write and Run.

### Reading memory contents:

To inspect a single memory location you can just type the address followed by RETURN, and the value stored in that memory location will be displayed, for example if you type:
```
10010
```
you may see something like:
```
00010010: 74
```

To examine a range from the last previously opened location you can enter:
```
.10210
```
and it will print out all values from 0x10010 to 0x10210.

You can also specify both ends of the range, in that case:
```
10010.10210
```
will produce the same result. When you enter a range like this, the _first_ address in the range will be saved as the last opened address for any operations that need to use it, until another specific range or individual address examination updates it.

Also you can enter various individual addresses to examine, for example if you enter:
```
10010 1001A 10023
```

You'll see something like:
```
00010010: 77
0001001A: 74
00010023: 70
```

And you can combine the above forms into a single line:
```
2C150.2C250 C000 1001A F0.FF CC
```
which will output something like:
```
0002C150: 70 40 2D E9 38 40 9F E5 00 20 A0 E3 B0 20 C4 E1
0002C160: 00 50 D0 E5 05 60 A0 E1 F0 60 06 E2 0F 50 05 E2
0002C170: 26 62 A0 E1 06 00 A0 E1 8B 02 00 EB 00 00 C4 E5
0002C180: 05 00 A0 E1 88 02 00 EB 01 00 C4 E5 04 00 A0 E1
0002C190: 70 80 BD E8 32 00 01 00 F0 4F 2D E9 10 42 9F E5
0002C1A0: 04 50 A0 E1 08 50 85 E2 00 60 A0 E1 04 72 9F E5
0002C1B0: 00 80 A0 E3 00 A0 A0 E3 00 90 A0 E3 00 B0 D6 E5
0002C1C0: 00 00 5B E3 68 00 00 0A 0A 00 5B E3 66 00 00 0A 
0002C1D0: 2E 00 5B E3 12 00 00 0A 3A 00 5B E3 2A 00 00 0A
0002C1E0: 52 00 5B E3 42 00 00 0A 20 00 5B E3 54 00 00 1A
0002C1F0: 00 00 58 E3 09 00 00 0A 00 00 A0 E3 08 00 C7 E7
0002C200: 07 00 A0 E1 77 02 00 EB 00 00 85 E5 04 50 85 E2
0002C210: 01 A0 8A E2 00 80 A0 E3 0C 00 5A E3 52 00 00 0A
0002C220: 4F 00 00 EA 00 00 59 E3 03 00 00 0A 01 00 59 E3
0002C230: 01 00 00 0A 00 40 A0 E3 5B 00 00 EA 00 00 58 E3
0002C240: 09 00 00 0A 00 00 A0 E3 08 00 C7 E7 07 00 A0 E1
0002C250: 64
0000C000: 00
0001001A: 74
000000F0: FF FF 00 FF 00 00 00 00 00 00 00 20 00 00 00 00
000000CC: 0E
```

### Writing to memory

To write a value to a memory location you can enter it in the form of _addr: value_, for example:
```
C000: FF
```
will write the value **FF** to memory location **C000**.

You can also write multiple values in a single line like:
```
C000: DE AD CA FE
```

And write from the last opened address:
```
:FF 00 DC 00
```

### Running a program at a specific location

To run a program at a specific memory location you have to enter the address where the program text begins followed by the **R** character, for example:
```
2C150 R
```
will run a program stored at address 2C150.

## Running the monitor

To run the monitor you have to either replace the `kernel.img` file of an SD card that already has an OS for the RPi1-ModB in it (rename or backup the old image first!) in the boot partition with the `kernel.img` file in the project's `/dist` directory, or use any SD card that has a FAT partition at the beginning of the partition table and copy the files in `/dist` into it (you don't actually need the .list and .map files so those can be omitted).

## Building from sources

To build this project for sources you need the GNU ARM Toolchain. If you're running Debian or Ubuntu you can get it via `apt` by installing the package **gcc-arm-none-eabi**.

The project can then be build by running the build script `build.sh`. There should be a proper makefile at some point but for now this has served well.

## Other notes

The project's directory tree is organized as follows:

-`/dist`: contains the distributable files.
-`/docs`: additional external documentation related to the project.
-`/ext`: external resources, contains the binary to produce the Signetics 2513 character generator font.
-`/lib`: library dependencies, contains the **csud** library for the keyboard/mouse USB driver.
-`/obj`: object files are put here by the build script. The content of this directory is ignored.
-`/src`: the project sources.
-`/`: build and linker scripts.

### Organization of sources

The sources in the `/src` directory are mostly of four types, either hardware drivers, program logic, glue between both, or other misc. helpers.

The files _mailbox.s_,  _video.s_ and _keyboard.s_ are the mailbox and video hardware drivers and some glue/middleware for the library that implements the USB keyboard driver.

The files _monitor.s_, _parser.s_, _proc.s_ and _util.s_ contain the program logic and the necessary utility functions to implement it.

The file _term.s_ is an abstraction on top of the video and keyboard drivers in the form of a terminal driver.

Finally _error.s_, _globals.s_ contain misc. helper macro and func. definitions, and _main.s_ contains the initialization and main loop code.

### About the style

Be warned that the style used in the sources can be totally inconsistent, between files and even within the same file.

The reason is that as I made progress with the writing, I experimented with different styles and idioms for writing ARM assembly, as well as with the different options of the instruction set itself.

This may result for example in some functions using `.req` aliases while some others not. Also at some point I also started using mostly registers starting from **r4** within functions for function-scoped variables and leaving the registers **r0-r3** to use as temp./aux. until the end of the function.  

Any performance/space optimizations were left completely out of the question and I haven't even bothered trying, so many things can still be improved.

I tried also to avoid "clever" tricks whenever possible and to consistently keep the code heavily commented.

## Resources

The following resources were invaluable to me for the development of this little project:

- The Embedded Linux RPi wiki, particularly for working with the framebuffer of the BCM2835.
https://elinux.org/RPi_Framebuffer

- The handy RPi wiki for programming the Mailboxes.
https://github.com/raspberrypi/firmware/wiki

- A wonderful tutorial on ARM assembly on the RPi 1 that got me started and that I kept going back throughout the project on several occassions.
http://www.cl.cam.ac.uk/projects/raspberrypi/tutorials/os/index.html

- Also not possible to overstate the importance of the USB keyboard library provided with the above tutorial, as without it the implementation of this program would have taken way longer to complete.
https://github.com/Chadderz121/csud

- The examples and detailed explanations in this repository:
https://github.com/dwelch67/raspberrypi

- A detailed description of the WOZ Monitor, both from a user perspective and also its internals with the source code & commentary on it.
https://www.sbprojects.net/projects/apple1/wozmon.php
