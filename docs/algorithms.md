# Algorithms

## Overview

The project uses a deliberately small set of deterministic algorithms chosen for artistic control, readability, and real-time performance. The system is not physically based. It is composition-driven procedural rendering.

## 1. Seed Mixing and Descriptor Generation

Implemented in `src/relic_rules.f90`.

### Purpose

Produce distinct but reproducible relic identities from a single integer seed.

### Process

1. Start from a base seed
2. Offset the seed per descriptor using a fixed stride
3. Mix the seed with integer arithmetic and bit operations
4. Mask to a positive integer range
5. Normalize to `[0, 1]`
6. Map normalized values into artistic parameter ranges

### Generated Parameters

- symmetry count
- ring count
- glyph density
- fracture amount
- emissive hue bias
- pulse speed

### Why this approach

- deterministic
- fast
- no external random-number state
- easy to keep stable across runs

## 2. Dominant Relic Selection

Implemented in `src/relic_state.f90`.

### Purpose

Choose one relic to anchor the composition.

### Process

Each descriptor is scored with a weighted sum of:

- resonance strength
- pulse intensity
- symmetry
- ring count
- inverse fracture amount

The highest score becomes the dominant relic.

### Result

The dominant relic receives:

- the most central placement
- the strongest composition weight
- the shallowest layer depth
- a larger region scale

This prevents all relics from competing equally for attention.

## 3. Scene Layout and Secondary Relic Placement

Implemented in `src/relic_state.f90`.

### Dominant placement

The dominant relic is placed near an anchored chamber center. Its exact position is nudged by hue bias and fracture level, but constrained to a narrow range to preserve composition.

### Secondary placement

Secondary relics are placed around the dominant one using:

- angle selection across a bounded arc
- orbital radius based on ring count and slot order
- vertical offset tied to glyph density
- clamped screen-space placement

### Supporting derived parameters

For each relic the scene builder computes:

- normalized symmetry and ring values
- region scale
- region rotation
- layer depth
- composition weight
- overlap softness
- pulse phase
- resonance strength

The output is a packed array model optimized for GPU upload.

## 4. Elliptical Region Metric

Implemented in `src/field_simulation.f90` and conceptually mirrored in the fragment shader.

### Purpose

Represent each relic as an oriented elliptical zone rather than a point.

### Formula

For a point `p`:

1. subtract relic center
2. rotate into relic-local space
3. divide by relic scales
4. compute squared length

This produces an anisotropic distance metric.

### Why it matters

- relics can have readable silhouette zones
- regions can be stretched and rotated
- overlap is controllable and art-directable

## 5. Resonance Field Initialization

Implemented in `src/field_simulation.f90`.

### Purpose

Seed a shared scalar field from the composed relic layout.

### Process

For each grid cell:

1. evaluate each relic’s elliptical metric
2. convert metric to a soft region mask with exponential falloff
3. add a base pulse term scaled by resonance strength, pulse intensity, composition weight, and glyph density
4. add a ring-emphasis term for structured inner activation
5. accumulate overlap energy
6. add a shared chorus term when overlap crosses a threshold

### Result

The initialized field already contains:

- localized relic activation
- soft overlap zones
- a minimum energy floor

## 6. Field Simulation Step

Implemented in `src/field_simulation.f90`.

### Purpose

Keep the scene alive with coherent, low-cost motion.

### Update rule

For each interior cell:

1. compute the four-neighbor average
2. compute relaxation as neighbor average minus center value
3. recompute per-relic region masks
4. generate time-varying wave terms using:
   - elapsed time
   - pulse speed
   - local radial distance
   - symmetry
   - fracture amount
   - pulse phase
5. inject pulse energy into the field
6. accumulate overlap energy
7. compute a modulated shared chorus term
8. integrate the next value with decay, relaxation, and injection
9. clamp into `[0, 1]`

### Boundary condition

Edge cells are damped instead of fully simulated to avoid unstable wrapping behavior.

## 7. Scene Shader Composition

Implemented in the scene fragment shader inside `src/gl_bridge.c`.

### Inputs

- relic parameter arrays
- resonance field texture
- camera state
- time
- output resolution

### Main stages

1. project screen UV into the scene plane using camera yaw, pitch, position, and field of view
2. sample the resonance field and approximate its gradient
3. construct chamber-scale mist, dust, and vault shaping from procedural noise
4. evaluate each relic region for presence and halo contribution
5. accumulate shared atmosphere from all relics
6. evaluate detailed relic structure:
   - shell bands
   - inner bands
   - symmetry ribs
   - rune-like radial modulation
   - fracture masking
   - focus cores
7. apply overlap relief so crowded regions remain readable
8. darken silhouette zones
9. add layered glow and detail
10. apply a final tonemapping curve

### Core design goal

The shader avoids treating the field as a full image source. Instead, the field acts as a continuity signal while the relic descriptors remain the primary source of structure.

## 8. Post-Processing Pass

Implemented in the post fragment shader inside `src/gl_bridge.c`.

### Bloom approximation

The shader samples a small neighborhood around the current pixel, extracts bright regions using a luminance threshold, and accumulates a weighted blur-like contribution.

### Tone shaping

The presented image is scaled by exposure and compressed using a simple rational tonemapping step.

### Vignette

A radial falloff darkens the edges of the frame to keep the eye inside the chamber.

### Why single-pass post

- simpler resource model
- low overhead
- easy to keep interactive
- sufficient for this project’s showcase goals

## 9. Screenshot Export

Implemented in `src/gl_bridge.c`.

### Process

1. create the output directory if required
2. find the next free sequential filename
3. read the presented back buffer
4. write rows in reverse order to correct OpenGL’s bottom-up origin
5. store the image as binary `P6` PPM

### Reasoning

This algorithm is intentionally boring and reliable. The project prioritizes a frictionless showcase path over a feature-rich export stack.
