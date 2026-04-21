# Methods and Rendering Techniques

## Overview

This document describes the practical methods used in Harmonic Relic Foundry to keep the renderer expressive, modular, and interactive.

## 1. Data-Oriented Scene Packing

The renderer does not pass complex object graphs into OpenGL. Instead, the scene is flattened into fixed-size arrays of scalar parameters:

- symmetry
- ring count
- glyph density
- fracture amount
- hue bias
- pulse speed
- pulse intensity
- region center
- region scale
- region rotation
- layer depth
- composition weight
- overlap softness
- pulse phase

This is a pragmatic method for GPU interoperability:

- the CPU side stays explicit
- uniform uploads are straightforward
- the scene stays easy to inspect and debug

## 2. Fixed-Step Simulation With Variable Render Rate

The program separates simulation timing from rendering timing.

Method:

- frame time is measured each loop
- the delta is clamped
- the scalar field advances in fixed `1/60` second substeps
- at most four substeps are processed per render frame

Benefits:

- stable simulation behavior
- predictable motion under variable frame time
- protection against runaway update loops

## 3. Controlled Procedural Layering

The image is built from several controlled procedural layers rather than a single complex equation.

Major layers:

- chamber atmosphere
- relic presence masks
- silhouette occlusion
- layered glow
- glyph and shell detail
- post-processing bloom and vignette

This method keeps the scene readable because each layer has a clear artistic job.

## 4. Dominant-versus-Secondary Composition

The renderer treats composition as a first-class method.

Instead of giving all relics equal importance, the scene builder:

- selects a dominant relic
- anchors it near the visual center
- enlarges and foregrounds it
- arranges secondary relics around it
- reduces secondary competition through depth and composition weight

This method is the main reason the result reads like a chamber instead of a particle cloud.

## 5. Hybrid Interaction Method

Interaction uses GLFW only and avoids a full GUI toolkit.

Method:

- keys for deterministic scene variation
- mouse drag for primary look control
- arrow keys and keyboard zoom as stable fallbacks
- title bar and console output for state reporting

Benefits:

- low code surface
- portable input path
- minimal runtime complexity

## 6. Two-Pass Rendering Method

The renderer uses a clean pass split:

- scene pass to an off-screen framebuffer
- presentation pass to the default framebuffer

Why this method matters:

- post-processing can be toggled cleanly
- capture happens after presentation shaping
- future post effects can be added without rewriting scene shading

## 7. Lightweight Post-Processing

The post pipeline deliberately avoids a heavyweight graph or compute stage.

Current methods:

- bright-region neighborhood accumulation for bloom
- exposure scaling and simple tone shaping
- radial vignette

This keeps the project showcase-ready without turning it into an engine framework.

## 8. Bridge-Based Platform Isolation

Platform-specific and API-specific behavior is isolated in the C bridge.

Examples:

- GLFW initialization
- OpenGL function loading
- shader compilation
- framebuffer creation
- `glReadPixels` capture logic

The Fortran code therefore remains focused on:

- simulation
- control state
- deterministic scene generation
- orchestration

## 9. Capture Method

Still capture uses a queue-like flag rather than an immediate blocking tool path.

Method:

- input sets a capture request flag
- rendering completes normally
- the presented framebuffer is read back once
- output is written to a project-local sequential filename

This keeps capture integrated into the normal render loop and avoids a separate export mode.

## 10. Performance Method

The project favors disciplined real-time costs over maximal effect complexity.

Examples:

- fixed relic count
- single scalar field
- fullscreen quad rendering
- lightweight bloom approximation
- no external textures
- no dynamic scene graph allocation during steady-state rendering

The general method is to bias toward art direction first, then choose the simplest technique that produces the intended visual result.
