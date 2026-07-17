# Changelog
All notable changes to this project will be documented in this file.

## Release [20260717]

### Fixed
- **Direct Video**: Fixed Direct Video output, which was not working in the previous release.
- **Black Widow Mapping**: Corrected the default Fire Up and Fire Down mappings when loading the RBF without an MRA.
- **Lunar Battle Controls**: Corrected the control wiring for the later prototype, restoring Start 1P/2P and the proper Fire, Thrust, and Shield inputs.
- **Lunar Battle Settings**: Added the correct gameplay DIP switches and defaults, together with the Diagnostic Step control.

### Added
- **Direct Video Scan Rate**: Added explicit selection between 15 kHz (240p) and 31 kHz (480p) output when Direct Video is active.

### Changed
- **Core Name**: Changed the embedded core name to Black Widow, so core-specific `mister.ini` settings now use the `[Black Widow]` header.
- **Fire Option**: Clarified the wording and intended use of both settings.

## Release [20260716]

### Update Notes
- **Config Reset Recommended**: Delete existing MiSTer config files for this core before first launch. Typically these files are found under `/media/fat/config/`, but your setup may vary.
- **SDRAM Requirement**: The CRT-style effects pipeline uses MiSTer SDRAM and requires a 32MB SDRAM module or larger.
- **Updated MRAs Recommended**: Use the included MRAs for the corrected DIP-switch mappings, auxiliary coin input, and diagnostic controls.

### Added
- **Ultra High Performance Renderer**: Replaced the legacy 640x480 rasterizer with a new custom vector renderer designed for CRT-style effects and high-resolution output (1080p recommended!).
- **New CRT Video Pipeline**: Added bloom, halo, phosphor decay, color processing, dot scaling, and an authentic slot mask.
- **Video Profiles**: Added five presets and two independent custom slots exposing the complete advanced control set. Profiles include A Touch of CRT, 80s Cruise Control, 80s Overdrive, Neon Fever Dream, and Pinktoe Tarantula.
- **Phosphor Decay**: Each pixel's draw time is recorded to allow for phosphor decay effects.
- **Toe Color Mode**: Added a color mode that changes the appearance of the spider into a Pinktoe Tarantula.
- **Video Controls**: Added Optimized, Stretched, and Pixel Perfect aspect modes, plus 120Hz output for 720p.
- **Operator Controls**: Added auxiliary coin input and exposed the original diagnostic-step and vector-test controls where supported.

### Changed
- **PROM-Driven Vector Generator**: Replaced the previous behavioral vector generator with an implementation driven by the original AVG state PROM.
- **Original Hardware Timing**: The CPU and vector generator now operate from the original 12.096MHz clock.
- **CPU Core**: Updated the T65 implementation and corrected decimal-mode, reset, and interrupt behavior.
- **Video Defaults**: 80s Cruise Control is now the default profile, and pausing when the OSD opens now defaults to Off.
- **Arcade Configuration**: Corrected and harmonized DIP-switch names, values, defaults, and menu ordering for Black Widow, Gravitar, and Lunar Battle.
