# Technical Architecture

## Overview

Harmonic Relic Foundry is organized as a small layered runtime with a clear division of responsibility:

- Modern Fortran owns scene logic, simulation state, and high-level application flow
- A thin Fortran interoperability module exposes the C bridge in a type-safe way
- A C/GLFW/OpenGL layer owns the window, input polling, shader setup, render passes, and image capture

This separation keeps the procedural art logic in Fortran while using GLFW and OpenGL through a compact native bridge rather than distributing platform details across the Fortran codebase.

## Runtime Layers

### 1. Application Layer

`src/main.f90` contains the top-level runtime loop.

Responsibilities:

- initialize the platform bridge
- initialize camera and relic control state
- rebuild scene data when the seed or live parameters change
- run the fixed-timestep field simulation
- send packed scene arrays and field textures to the renderer
- trigger the scene pass, presentation pass, and optional capture path

The main loop uses a fixed simulation timestep of `1/60` seconds and clamps frame delta to avoid instability during long frames.

### 2. Scene Description Layer

`src/relic_rules.f90` and `src/relic_state.f90` together define the content model.

`relic_rules.f90` is responsible for deterministic descriptor generation:

- integer seed mixing
- normalized pseudo-random values
- mapping random values into artistic parameter ranges

`relic_state.f90` turns descriptors into a scene:

- computes normalized shader-facing arrays
- chooses the dominant relic
- places the dominant relic near the composition anchor
- places secondary relics around it with bounded offsets
- computes scale, depth, overlap softness, pulse phase, and composition weights

The output of this layer is a packed `relic_scene_state` that is convenient for both simulation and shader upload.

### 3. Simulation Layer

`src/field_simulation.f90` provides a lightweight scalar field that acts as shared atmospheric motion across the relic set.

The field:

- is initialized from the relic regions
- stores current and next buffers
- evolves through a simple relaxation-and-injection step
- produces overlap energy where relic fields interact

This field is uploaded every frame as a single-channel float texture and sampled by the fragment shader to drive atmosphere, cracking, gradients, and cross-relic continuity.

### 4. Input and Control Layer

`src/exploration_controls.f90` centralizes user interaction.

It converts raw platform input into:

- camera translation
- yaw and pitch updates
- field-of-view changes
- seed cycling
- symmetry, glyph-density, and pulse-intensity variation
- post-processing toggle and capture requests

This module intentionally avoids GUI code. Runtime state is represented as plain data structures that remain easy to serialize, print, or reuse later.

### 5. Interop Layer

`src/platform_gl.f90` is the Fortran interoperability boundary.

It exposes `bind(C)` interfaces for:

- window creation and shutdown
- input polling
- camera updates
- field texture uploads
- relic parameter uploads
- post-processing parameters
- capture requests
- frame rendering

This module keeps C interoperability code out of the higher-level scene and simulation modules.

### 6. Native Rendering Layer

`src/gl_bridge.c` owns platform and GPU interaction.

Responsibilities:

- initialize GLFW and the OpenGL context
- load OpenGL procedure pointers
- compile and link the scene shader and post-processing shader
- keep renderer-global GPU resources alive
- poll GLFW input and convert it into a bridge-friendly struct
- render to an off-screen framebuffer
- present the final image through a fullscreen post-processing pass
- save screenshots as binary `PPM` files

## Data Flow

The frame pipeline is:

1. `main.f90` polls platform input
2. `exploration_controls.f90` updates camera and relic control state
3. If scene controls changed, `relic_rules.f90` and `relic_state.f90` rebuild the scene
4. `field_simulation.f90` advances the resonance field on a fixed timestep
5. `platform_gl.f90` uploads:
   - camera state
   - relic arrays
   - field texture
   - post-processing settings
6. `gl_bridge.c` renders the scene to an off-screen framebuffer
7. `gl_bridge.c` runs the presentation shader on a fullscreen quad
8. If requested, the presented frame is read back and saved

## Why the Fortran/OpenGL Split Works

This codebase uses Fortran where it adds value:

- compact numeric code
- explicit data structures
- good fit for simulation and deterministic procedural generation

It uses C where it is pragmatic:

- direct GLFW integration
- direct OpenGL API access
- function pointer loading
- platform-adjacent resource management

The bridge remains narrow and data-oriented, which keeps the boundary understandable and reduces accidental coupling.

## Shader Architecture

The renderer uses two fragment programs:

- a scene shader
- a post-processing shader

The scene shader consumes:

- resolution
- time
- camera state
- relic arrays
- the resonance field texture

It produces the chamber image into an off-screen floating-point color buffer.

The post-processing shader consumes:

- the scene color texture
- output resolution
- post-processing parameters

It applies bloom, exposure shaping, and vignette before presentation.

## Capture Path

Still capture is intentionally simple.

The renderer:

- ensures a relative output directory exists
- finds the next free filename
- reads the back buffer using `glReadPixels`
- writes a binary `P6` PPM file

This avoids heavyweight image dependencies while remaining portable and easy to audit.

## Extensibility

The current structure is suitable for future additions without architectural rewrite:

- more relic descriptors
- animation presets
- post-processing expansion
- export formats beyond PPM
- recorded camera paths
- additional simulation buffers
- offline still or sequence rendering
