! Descriptor generation utilities for producing distinct relic identities
! from deterministic integer seeds.
module relic_rules
  use, intrinsic :: iso_c_binding, only: c_float, c_int
  implicit none
  private

  public :: relic_descriptor
  public :: generate_relic_descriptor

  type :: relic_descriptor
    integer(c_int) :: seed = 0_c_int
    integer(c_int) :: symmetry_count = 0_c_int
    integer(c_int) :: ring_count = 0_c_int
    real(c_float) :: glyph_density = 0.0_c_float
    real(c_float) :: fracture_amount = 0.0_c_float
    real(c_float) :: emissive_hue_bias = 0.0_c_float
    real(c_float) :: pulse_speed = 0.0_c_float
  end type relic_descriptor

contains

  pure function mix_seed(seed, stream) result(value)
    integer(c_int), intent(in) :: seed
    integer(c_int), intent(in) :: stream
    integer(c_int) :: value

    value = ieor(seed * 1103515245_c_int + 12345_c_int, stream * 214013_c_int + 2531011_c_int)
    value = ieor(value, ishft(value, -16))
    value = value * 16807_c_int + 17_c_int * stream
    value = ieor(value, ishft(value, -16))
  end function mix_seed

  pure function normalized_value(seed, stream) result(value)
    integer(c_int), intent(in) :: seed
    integer(c_int), intent(in) :: stream
    real(c_float) :: value
    integer(c_int) :: mixed
    integer(c_int), parameter :: positive_mask = int(z'7fffffff', c_int)

    mixed = iand(mix_seed(seed, stream), positive_mask)
    value = real(mixed, c_float) / real(positive_mask, c_float)
  end function normalized_value

  pure function map_range(unit_value, min_value, max_value) result(mapped)
    real(c_float), intent(in) :: unit_value
    real(c_float), intent(in) :: min_value
    real(c_float), intent(in) :: max_value
    real(c_float) :: mapped

    mapped = min_value + (max_value - min_value) * unit_value
  end function map_range

  pure function generate_relic_descriptor(seed, index) result(descriptor)
    integer(c_int), intent(in) :: seed
    integer(c_int), intent(in) :: index
    type(relic_descriptor) :: descriptor
    integer(c_int) :: local_seed

    local_seed = seed + index * 977_c_int

    descriptor%seed = local_seed
    descriptor%symmetry_count = 3_c_int + int(7.0_c_float * normalized_value(local_seed, 1_c_int), c_int)
    descriptor%ring_count = 2_c_int + int(5.0_c_float * normalized_value(local_seed, 2_c_int), c_int)
    descriptor%glyph_density = map_range(normalized_value(local_seed, 3_c_int), 0.18_c_float, 0.92_c_float)
    descriptor%fracture_amount = map_range(normalized_value(local_seed, 4_c_int), 0.05_c_float, 0.75_c_float)
    descriptor%emissive_hue_bias = map_range(normalized_value(local_seed, 5_c_int), -0.85_c_float, 0.85_c_float)
    descriptor%pulse_speed = map_range(normalized_value(local_seed, 6_c_int), 0.20_c_float, 1.35_c_float)
  end function generate_relic_descriptor

end module relic_rules
