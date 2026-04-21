# Harmonic Relic Foundry

Harmonic Relic Foundry is a real-time procedural rendering project built with Modern Fortran, C, OpenGL, and GLFW. It generates an explorable symbolic chamber of interacting relic structures: a dominant shrine-like form, secondary supporting regions, a shared resonance field, and a procedural presentation pass for bloom, vignette, and still capture.

## Artistic Direction

The project is designed as symbolic machine-archaeology rather than a conventional shader toy. The target image is an impossible shrine: layered, luminous, and legible. Composition matters more than raw visual density. The dominant relic anchors the frame, secondary relics create spatial conversation around it, and the shared field provides motion without dissolving the image into noise.

## Features

- Deterministic relic generation from integer seeds
- Dominant-versus-secondary scene composition
- Interactive camera exploration and live scene variation
- Shared resonance-field simulation
- Two-pass rendering with off-screen scene rendering and procedural post-processing
- Still-image export to a local `captures/` directory
- Clean Fortran-to-C bridge instead of UI-heavy runtime plumbing

## Requirements

- Linux or WSL2 with working OpenGL display support
- `gfortran`
- `gcc`
- `cmake`
- GLFW development headers and libraries
- Mesa / OpenGL development headers and libraries

## Setup

Use the root-level installer on apt-based systems:

```bash
./install_requirements.sh
```

Manual package installation equivalent:

```bash
sudo apt-get install gfortran gcc cmake build-essential mesa-utils libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev xorg-dev
```

## Build

Fast path:

```bash
./build.sh
```

Equivalent raw CMake commands:

```bash
cmake -S . -B build
cmake --build build -j4
```

## Run

Fast path:

```bash
./run.sh
```

Equivalent direct binary launch from the repository root:

```bash
./build/harmonic_relic_foundry
```

## Controls

- `W A S D Q E`: move camera
- Left mouse drag: look around
- Arrow keys: fallback orbit/look control
- Mouse wheel: zoom / change field of view
- `Z` / `X`: keyboard zoom fallback
- `1` / `2`: cycle seed
- `3` / `4`: adjust symmetry count
- `5` / `6`: adjust glyph density
- `7` / `8`: adjust pulse intensity
- `O`: toggle post-processing
- `C`: capture the current frame
- `P`: print current state to the console

The window title reports seed, symmetry offset, glyph bias, pulse scale, field of view, and post-processing state. The console prints a readable summary on startup and when requested.

## Capture / Export

Press `C` during runtime to save the currently presented frame as a binary `PPM` image.

- Running from the repository root writes captures to `<repo>/captures/`
- Running from `build/` writes captures to `build/captures/`

The export path is intentionally dependency-light:

- no external image library
- no absolute paths
- no editor-specific tooling

## Repository Layout

```text
.
├── CMakeLists.txt
├── README.md
├── .gitignore
├── build.sh
├── docs/
│   ├── algorithms.md
│   ├── methods.md
│   └── technical-architecture.md
├── install_requirements.sh
├── requirements-build.txt
├── requirements-runtime.txt
├── run.sh
├── scripts/
│   └── setup_env.sh          # compatibility wrapper
└── src/
    ├── exploration_controls.f90
    ├── field_simulation.f90
    ├── gl_bridge.c
    ├── main.f90
    ├── platform_gl.f90
    ├── relic_rules.f90
    └── relic_state.f90
```

## Technical Documentation

- [Technical Architecture](docs/technical-architecture.md)
- [Algorithms](docs/algorithms.md)
- [Methods and Rendering Techniques](docs/methods.md)

## Limitations

- The current composition uses exactly three relic descriptors
- Screenshot output is `PPM`, not `PNG`
- Bloom is a lightweight single-pass approximation rather than a full blur chain
- Runtime state display is limited to the window title and console output
- The project currently targets Linux and WSL2-style OpenGL environments
