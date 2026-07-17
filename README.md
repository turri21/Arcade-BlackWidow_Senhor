-=(BlackWidow_Senhor notes)=-

Tested: Working Video 720p, 1080p & Sound.

Dev notes: Clocks swapped in sys.tcl (not needed any more)

___
# Black Widow

FPGA implementation of Atari's **Black Widow**, with support for **Gravitar** and **Lunar Battle**, for the [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki) platform.

Based on the [original FPGA implementation](http://spritesmods.com/?art=bwidow_fpga) by Jeroen Domburg, with contributions from james10952001, Dave Woo, and fpgaarcade.com. Ported to MiSTer by Alan Steremberg.

This release adds a PROM-driven Atari Analog Vector Generator and a new Ultra High Performance Renderer with high-resolution output and CRT-style video effects.

## Requirements

The CRT-style effects pipeline requires a 32MB MiSTer SDRAM module or larger.

When updating from an older release, delete the existing MiSTer config files for this core before first launch. Typically these are found under `/media/fat/config/`, but your setup may vary.

Use the included MRA files so the DIP switches, auxiliary coin input, and diagnostic controls are mapped correctly.

## Video

The new renderer supports 240p, 480p, 720p, and 1080p output. **1080p is recommended** for the highest detail. Compatible 720p displays can also use the optional 120Hz mode.

The **Profile** option provides five presets: A Touch of CRT, 80s Cruise Control, 80s Overdrive, Neon Fever Dream, and Pinktoe Tarantula. Custom 1 and Custom 2 expose the complete advanced effects controls, while Off bypasses the CRT effects.

Pinktoe Tarantula uses the Toe color mode to give Black Widow's spider a distinctive pinktoe appearance.

Aspect ratio options are Optimized, Stretched, and Pixel Perfect.

> **Warning:** Neon Fever Dream and Pinktoe Tarantula feature excessive flashing bright lights.

## Controls

Black Widow uses independent directional controls for movement and firing. The **Fire** option selects how the four firing directions are mapped:

- **Buttons**: Uses four assignable inputs on the Player 1 controller. These can be face buttons or directions on a second analog stick.
- **Second Joystick**: Uses the directional input of a separate controller assigned as Player 2.

Keyboard controls use MiSTer's joystick emulation and must be configured through **Define joystick buttons** in the Menu core. JAMMA/IPAC-style interfaces can use the standard arcade keyboard layout.

## Hiscore save/load

Save and load of hiscores is supported for the following games on this core:
 - Black Widow
 - Gravitar

To save your hiscores manually, press the 'Save Settings' option in the OSD.  Hiscores will be automatically loaded when the core is started.

To enable automatic saving of hiscores, turn on the 'Autosave Hiscores' option, press the 'Save Settings' option in the OSD, and reload the core.  Hiscores will then be automatically saved (if they have changed) any time the OSD is opened.

Hiscore data is stored in /media/fat/config/nvram/ as ```<mra filename>.nvm```

## ROMs
```
                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip

```
