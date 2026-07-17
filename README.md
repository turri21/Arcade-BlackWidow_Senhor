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

For the highest-detail output, add the following under the exact `[Black Widow]` header in `mister.ini`. MiSTer's scaler filters and shadow mask should be disabled because the core provides its own CRT-effects pipeline and slot mask.

```ini
[Black Widow]
video_mode=8
vscale_mode=0
vfilter_default=
vfilter_vertical_default=
vfilter_scanlines_default=
shmask_default=
shmask_mode_default=0
```

When Direct Video is active, use **Direct Video Scan Rate** in Video Options to select 15 kHz (240p) or 31 kHz (480p) output.

When using a real CRT, consider starting with **A Touch of CRT** or a **Custom** profile. Most other profiles recreate characteristics that the tube itself already provides, including phosphor-mask structure, color response, bloom, and halo. A Custom profile lets you reduce or disable duplicated effects while retaining the processing that benefits your display.

The **Profile** option provides five presets: A Touch of CRT, 80s Cruise Control, 80s Overdrive, Neon Fever Dream, and Pinktoe Tarantula. Custom 1 and Custom 2 expose the complete advanced effects controls, while Off bypasses the CRT effects.

Pinktoe Tarantula uses the Toe color mode to give Black Widow's spider a distinctive pinktoe appearance.

Aspect ratio options are Optimized, Stretched, and Pixel Perfect.

> **Warning:** Neon Fever Dream and Pinktoe Tarantula feature excessive flashing bright lights.

## Controls

Black Widow uses independent directional controls for movement and firing. The **Fire Controls** option selects where the four firing directions are mapped:

- **Normal**: Uses four independently assignable inputs on the same controller as movement. These may be mapped to a second stick or buttons.
- **P2 Controller**: Uses the directional inputs of the controller assigned to Player 2. This mode is useful for arcade cabinet setups that provide separate Player 1 and Player 2 controls.

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
