! Scene-level relic composition: chooses a dominant relic, places
! secondary relic regions, and exposes packed arrays for rendering.
module relic_state
  use, intrinsic :: iso_c_binding, only: c_float, c_int
  use :: relic_rules, only: relic_descriptor, generate_relic_descriptor
  implicit none
  private

  integer(c_int), parameter, public :: max_relic_descriptors = 3_c_int

  public :: relic_scene_state
  public :: initialize_relic_scene
  public :: apply_scene_variation
  type :: relic_scene_state
    integer(c_int) :: descriptor_count = 0_c_int
    integer(c_int) :: dominant_index = 1_c_int
    real(c_float) :: pulse_intensity_scale = 1.0_c_float
    type(relic_descriptor) :: descriptors(max_relic_descriptors)
    real(c_float) :: symmetry(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: ring_count(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: glyph_density(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: fracture_amount(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: emissive_hue_bias(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: pulse_speed(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: pulse_intensity(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: center_x(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: center_y(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: region_scale_x(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: region_scale_y(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: region_rotation(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: layer_depth(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: composition_weight(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: overlap_softness(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: pulse_phase(max_relic_descriptors) = 0.0_c_float
    real(c_float) :: resonance_strength(max_relic_descriptors) = 0.0_c_float
  end type relic_scene_state

contains

  pure real(c_float) function clamp_range(value, min_value, max_value) result(clamped)
    real(c_float), intent(in) :: value
    real(c_float), intent(in) :: min_value
    real(c_float), intent(in) :: max_value

    clamped = max(min_value, min(max_value, value))
  end function clamp_range

  pure real(c_float) function pulse_phase_from_seed(seed, stream) result(phase)
    integer(c_int), intent(in) :: seed
    integer(c_int), intent(in) :: stream
    real(c_float), parameter :: pi = acos(-1.0_c_float)

    phase = 2.0_c_float * pi * ( &
      0.5_c_float + 0.5_c_float * sin( &
        real(seed, c_float) * 0.0171_c_float + &
        real(stream, c_float) * 0.731_c_float &
      ) &
    )
  end function pulse_phase_from_seed

  subroutine refresh_relic_scene(scene)
    type(relic_scene_state), intent(inout) :: scene
    integer(c_int) :: i
    integer(c_int) :: slot
    integer(c_int) :: secondary_count
    real(c_float) :: angle
    real(c_float) :: orbit_radius
    real(c_float) :: slot_fraction
    real(c_float) :: best_score
    real(c_float) :: dominance_score
    real(c_float) :: anchor_x
    real(c_float) :: anchor_y
    real(c_float) :: dominant_symmetry
    real(c_float) :: dominant_rings
    real(c_float) :: dominant_glyphs
    real(c_float) :: dominant_fracture
    real(c_float), parameter :: inv_max_symmetry = 1.0_c_float / 9.0_c_float
    real(c_float), parameter :: inv_max_rings = 1.0_c_float / 6.0_c_float
    real(c_float), parameter :: pi = acos(-1.0_c_float)

    scene%dominant_index = 1_c_int
    best_score = -1.0_c_float

    do i = 1_c_int, scene%descriptor_count
      scene%symmetry(i) = real(scene%descriptors(i)%symmetry_count, c_float) * inv_max_symmetry
      scene%ring_count(i) = real(scene%descriptors(i)%ring_count, c_float) * inv_max_rings
      scene%glyph_density(i) = scene%descriptors(i)%glyph_density
      scene%fracture_amount(i) = scene%descriptors(i)%fracture_amount
      scene%emissive_hue_bias(i) = scene%descriptors(i)%emissive_hue_bias
      scene%pulse_speed(i) = scene%descriptors(i)%pulse_speed
      scene%pulse_phase(i) = pulse_phase_from_seed(scene%descriptors(i)%seed, i)
      scene%resonance_strength(i) = 0.30_c_float + 0.45_c_float * scene%glyph_density(i) + &
        0.20_c_float * (1.0_c_float - scene%fracture_amount(i))
      scene%pulse_intensity(i) = clamp_range( &
        scene%pulse_intensity_scale * ( &
          0.55_c_float + 0.30_c_float * scene%glyph_density(i) + 0.25_c_float * scene%ring_count(i) &
        ), &
        0.20_c_float, &
        2.80_c_float &
      )

      dominance_score = 0.38_c_float * scene%resonance_strength(i) + &
        0.18_c_float * scene%pulse_intensity(i) + &
        0.16_c_float * scene%symmetry(i) + &
        0.12_c_float * scene%ring_count(i) + &
        0.16_c_float * (1.0_c_float - scene%fracture_amount(i))

      if (dominance_score > best_score) then
        best_score = dominance_score
        scene%dominant_index = i
      end if
    end do

    dominant_symmetry = scene%symmetry(scene%dominant_index)
    dominant_rings = scene%ring_count(scene%dominant_index)
    dominant_glyphs = scene%glyph_density(scene%dominant_index)
    dominant_fracture = scene%fracture_amount(scene%dominant_index)

    anchor_x = clamp_range( &
      0.50_c_float + 0.05_c_float * scene%emissive_hue_bias(scene%dominant_index), &
      0.42_c_float, &
      0.58_c_float &
    )
    anchor_y = clamp_range( &
      0.55_c_float - 0.06_c_float * (dominant_fracture - 0.35_c_float), &
      0.44_c_float, &
      0.62_c_float &
    )

    scene%center_x(scene%dominant_index) = anchor_x
    scene%center_y(scene%dominant_index) = anchor_y
    scene%region_scale_x(scene%dominant_index) = 0.24_c_float + 0.10_c_float * dominant_rings + 0.05_c_float * dominant_glyphs
    scene%region_scale_y(scene%dominant_index) = 0.19_c_float + 0.12_c_float * dominant_glyphs + &
      0.04_c_float * (1.0_c_float - dominant_fracture) + 0.03_c_float * dominant_symmetry
    scene%region_rotation(scene%dominant_index) = 0.10_c_float * pi * scene%emissive_hue_bias(scene%dominant_index)
    scene%layer_depth(scene%dominant_index) = 0.14_c_float
    scene%composition_weight(scene%dominant_index) = 1.00_c_float
    scene%overlap_softness(scene%dominant_index) = 0.76_c_float

    secondary_count = scene%descriptor_count - 1_c_int
    slot = 0_c_int

    do i = 1_c_int, scene%descriptor_count
      if (i == scene%dominant_index) cycle

      slot = slot + 1_c_int
      if (secondary_count > 1_c_int) then
        slot_fraction = real(slot - 1_c_int, c_float) / real(secondary_count - 1_c_int, c_float)
      else
        slot_fraction = 0.5_c_float
      end if

      angle = -0.80_c_float * pi + slot_fraction * 1.45_c_float * pi + &
        0.35_c_float * scene%emissive_hue_bias(i)
      orbit_radius = 0.24_c_float + 0.08_c_float * scene%ring_count(i) + &
        0.04_c_float * real(slot, c_float) / real(max(secondary_count, 1_c_int), c_float)

      scene%center_x(i) = clamp_range(anchor_x + orbit_radius * cos(angle), 0.18_c_float, 0.82_c_float)
      scene%center_y(i) = clamp_range( &
        anchor_y + (0.20_c_float + 0.07_c_float * scene%glyph_density(i)) * sin(angle), &
        0.18_c_float, &
        0.82_c_float &
      )
      scene%region_scale_x(i) = 0.12_c_float + 0.08_c_float * scene%ring_count(i) + &
        0.05_c_float * (1.0_c_float - scene%fracture_amount(i))
      scene%region_scale_y(i) = 0.14_c_float + 0.08_c_float * scene%glyph_density(i) + &
        0.04_c_float * scene%symmetry(i)
      scene%region_rotation(i) = angle * 0.65_c_float
      scene%layer_depth(i) = 0.42_c_float + 0.28_c_float * slot_fraction
      scene%composition_weight(i) = min( &
        0.82_c_float, &
        0.54_c_float + 0.18_c_float * scene%glyph_density(i) + 0.10_c_float * (1.0_c_float - scene%layer_depth(i)) &
      )
      scene%overlap_softness(i) = min( &
        0.88_c_float, &
        0.34_c_float + 0.30_c_float * (1.0_c_float - scene%fracture_amount(i)) + 0.12_c_float * (1.0_c_float - slot_fraction) &
      )
    end do
  end subroutine refresh_relic_scene

  subroutine apply_scene_variation(scene, symmetry_offset, glyph_density_bias, pulse_intensity_scale)
    type(relic_scene_state), intent(inout) :: scene
    integer(c_int), intent(in) :: symmetry_offset
    real(c_float), intent(in) :: glyph_density_bias
    real(c_float), intent(in) :: pulse_intensity_scale
    integer(c_int) :: i

    scene%pulse_intensity_scale = clamp_range(pulse_intensity_scale, 0.20_c_float, 2.80_c_float)

    do i = 1_c_int, scene%descriptor_count
      scene%descriptors(i)%symmetry_count = max( &
        3_c_int, &
        min(9_c_int, scene%descriptors(i)%symmetry_count + symmetry_offset) &
      )
      scene%descriptors(i)%glyph_density = clamp_range( &
        scene%descriptors(i)%glyph_density + glyph_density_bias, &
        0.05_c_float, &
        0.98_c_float &
      )
    end do

    call refresh_relic_scene(scene)
  end subroutine apply_scene_variation

  subroutine initialize_relic_scene(seed, scene)
    integer(c_int), intent(in) :: seed
    type(relic_scene_state), intent(out) :: scene
    integer(c_int) :: i

    scene%descriptor_count = max_relic_descriptors
    scene%pulse_intensity_scale = 1.0_c_float

    do i = 1_c_int, scene%descriptor_count
      scene%descriptors(i) = generate_relic_descriptor(seed, i - 1_c_int)
    end do
    call refresh_relic_scene(scene)
  end subroutine initialize_relic_scene

end module relic_state
