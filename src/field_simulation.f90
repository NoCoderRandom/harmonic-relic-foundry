! Lightweight resonance-field simulation used to seed shared motion
! and overlap energy across the composed relic scene.
module field_simulation
  use, intrinsic :: iso_c_binding, only: c_float, c_int
  use :: relic_state, only: relic_scene_state
  implicit none
  private

  public :: field_simulation_state
  public :: initialize_field_simulation
  public :: step_field_simulation

  type :: field_simulation_state
    integer(c_int) :: width = 0_c_int
    integer(c_int) :: height = 0_c_int
    integer(c_int) :: cell_count = 0_c_int
    real(c_float) :: elapsed_time = 0.0_c_float
    real(c_float), allocatable :: current(:)
    real(c_float), allocatable :: next(:)
  end type field_simulation_state

contains

  pure integer(c_int) function field_index(width, x, y) result(index_value)
    integer(c_int), intent(in) :: width
    integer(c_int), intent(in) :: x
    integer(c_int), intent(in) :: y

    index_value = x + (y - 1_c_int) * width
  end function field_index

  pure real(c_float) function elliptical_metric( &
    px, py, center_x, center_y, scale_x, scale_y, rotation &
  ) result(metric)
    real(c_float), intent(in) :: px
    real(c_float), intent(in) :: py
    real(c_float), intent(in) :: center_x
    real(c_float), intent(in) :: center_y
    real(c_float), intent(in) :: scale_x
    real(c_float), intent(in) :: scale_y
    real(c_float), intent(in) :: rotation
    real(c_float) :: dx
    real(c_float) :: dy
    real(c_float) :: rotated_x
    real(c_float) :: rotated_y
    real(c_float) :: cos_angle
    real(c_float) :: sin_angle

    dx = px - center_x
    dy = py - center_y
    cos_angle = cos(rotation)
    sin_angle = sin(rotation)
    rotated_x = cos_angle * dx + sin_angle * dy
    rotated_y = -sin_angle * dx + cos_angle * dy
    metric = (rotated_x / max(scale_x, 1.0e-3_c_float)) ** 2 + &
      (rotated_y / max(scale_y, 1.0e-3_c_float)) ** 2
  end function elliptical_metric

  subroutine initialize_field_simulation(scene, width, height, field)
    type(relic_scene_state), intent(in) :: scene
    integer(c_int), intent(in) :: width
    integer(c_int), intent(in) :: height
    type(field_simulation_state), intent(inout) :: field
    integer(c_int) :: x
    integer(c_int) :: y
    integer(c_int) :: relic_index
    integer(c_int) :: index_value
    real(c_float) :: px
    real(c_float) :: py
    real(c_float) :: region_metric
    real(c_float) :: region_mask
    real(c_float) :: seed_pulse
    real(c_float) :: overlap_energy
    real(c_float) :: shared_chorus
    real(c_float), parameter :: inv255 = 1.0_c_float / 255.0_c_float

    field%width = width
    field%height = height
    field%cell_count = width * height
    field%elapsed_time = 0.0_c_float

    if (allocated(field%current)) deallocate(field%current)
    if (allocated(field%next)) deallocate(field%next)

    allocate(field%current(field%cell_count))
    allocate(field%next(field%cell_count))
    field%current = 0.0_c_float
    field%next = 0.0_c_float

    do y = 1_c_int, field%height
      py = real(y - 1_c_int, c_float) / real(max(field%height - 1_c_int, 1_c_int), c_float)
      do x = 1_c_int, field%width
        px = real(x - 1_c_int, c_float) / real(max(field%width - 1_c_int, 1_c_int), c_float)
        index_value = field_index(field%width, x, y)
        overlap_energy = 0.0_c_float

        do relic_index = 1_c_int, scene%descriptor_count
          region_metric = elliptical_metric( &
            px, &
            py, &
            scene%center_x(relic_index), &
            scene%center_y(relic_index), &
            scene%region_scale_x(relic_index), &
            scene%region_scale_y(relic_index), &
            scene%region_rotation(relic_index) &
          )
          region_mask = exp(-region_metric * (1.25_c_float + 0.75_c_float * scene%layer_depth(relic_index)))
          seed_pulse = region_mask * scene%resonance_strength(relic_index) * scene%pulse_intensity(relic_index) * &
            scene%composition_weight(relic_index) * &
            (0.12_c_float + 0.20_c_float * scene%glyph_density(relic_index))
          seed_pulse = seed_pulse + exp(-region_metric * (3.5_c_float + 4.0_c_float * scene%ring_count(relic_index))) * &
            scene%pulse_intensity(relic_index) * (0.04_c_float + 0.05_c_float * scene%ring_count(relic_index))
          overlap_energy = overlap_energy + region_mask * (0.45_c_float + 0.55_c_float * scene%overlap_softness(relic_index))
          field%current(index_value) = field%current(index_value) + &
            seed_pulse
        end do

        shared_chorus = max(0.0_c_float, overlap_energy - 0.90_c_float)
        field%current(index_value) = min( &
          1.0_c_float, &
          field%current(index_value) + 0.16_c_float * shared_chorus * shared_chorus + inv255 &
        )
      end do
    end do

    field%next = field%current
  end subroutine initialize_field_simulation

  subroutine step_field_simulation(field, scene, dt)
    type(field_simulation_state), intent(inout) :: field
    type(relic_scene_state), intent(in) :: scene
    real(c_float), intent(in) :: dt
    integer(c_int) :: x
    integer(c_int) :: y
    integer(c_int) :: relic_index
    integer(c_int) :: index_value
    integer(c_int) :: left_index
    integer(c_int) :: right_index
    integer(c_int) :: up_index
    integer(c_int) :: down_index
    real(c_float) :: clamped_dt
    real(c_float) :: px
    real(c_float) :: py
    real(c_float) :: center_value
    real(c_float) :: neighbor_average
    real(c_float) :: relaxation
    real(c_float) :: region_metric
    real(c_float) :: local_radial
    real(c_float) :: region_mask
    real(c_float) :: pulse
    real(c_float) :: wave
    real(c_float) :: overlap_energy
    real(c_float) :: shared_chorus
    real(c_float) :: next_value
    real(c_float), parameter :: relax_rate = 5.4_c_float
    real(c_float), parameter :: decay_rate = 1.30_c_float
    real(c_float), parameter :: injection_gain = 1.90_c_float

    clamped_dt = min(max(dt, 0.0_c_float), 0.05_c_float)
    field%elapsed_time = field%elapsed_time + clamped_dt

    do y = 1_c_int, field%height
      py = real(y - 1_c_int, c_float) / real(max(field%height - 1_c_int, 1_c_int), c_float)
      do x = 1_c_int, field%width
        index_value = field_index(field%width, x, y)
        center_value = field%current(index_value)

        if (x == 1_c_int .or. x == field%width .or. y == 1_c_int .or. y == field%height) then
          field%next(index_value) = center_value * 0.93_c_float
          cycle
        end if

        left_index = field_index(field%width, x - 1_c_int, y)
        right_index = field_index(field%width, x + 1_c_int, y)
        up_index = field_index(field%width, x, y - 1_c_int)
        down_index = field_index(field%width, x, y + 1_c_int)

        neighbor_average = 0.25_c_float * ( &
          field%current(left_index) + &
          field%current(right_index) + &
          field%current(up_index) + &
          field%current(down_index) &
        )
        relaxation = neighbor_average - center_value

        px = real(x - 1_c_int, c_float) / real(max(field%width - 1_c_int, 1_c_int), c_float)
        pulse = 0.0_c_float
        overlap_energy = 0.0_c_float

        do relic_index = 1_c_int, scene%descriptor_count
          region_metric = elliptical_metric( &
            px, &
            py, &
            scene%center_x(relic_index), &
            scene%center_y(relic_index), &
            scene%region_scale_x(relic_index), &
            scene%region_scale_y(relic_index), &
            scene%region_rotation(relic_index) &
          )
          local_radial = sqrt(region_metric)
          region_mask = exp(-region_metric * (1.05_c_float + 0.90_c_float * scene%layer_depth(relic_index)))
          wave = 0.5_c_float + 0.5_c_float * sin( &
            field%elapsed_time * (0.70_c_float + 2.80_c_float * scene%pulse_speed(relic_index)) + &
            local_radial * (10.0_c_float + 8.0_c_float * scene%symmetry(relic_index)) - &
            region_metric * (1.80_c_float + 3.50_c_float * scene%fracture_amount(relic_index)) + &
            scene%pulse_phase(relic_index) &
          )
          pulse = pulse + region_mask * wave * scene%resonance_strength(relic_index) * &
            scene%pulse_intensity(relic_index) * scene%composition_weight(relic_index) * &
            (0.36_c_float + 0.26_c_float * scene%glyph_density(relic_index))
          overlap_energy = overlap_energy + region_mask * scene%overlap_softness(relic_index) * &
            (0.70_c_float + 0.30_c_float * scene%pulse_intensity(relic_index))
        end do

        shared_chorus = max(0.0_c_float, overlap_energy - 0.95_c_float)
        shared_chorus = shared_chorus * ( &
          0.5_c_float + 0.5_c_float * sin(field%elapsed_time * 1.35_c_float + px * 6.0_c_float - py * 4.5_c_float) &
        )

        next_value = center_value + clamped_dt * ( &
          relax_rate * relaxation - &
          decay_rate * center_value + &
          injection_gain * pulse + &
          0.70_c_float * shared_chorus &
        )
        field%next(index_value) = min(1.0_c_float, max(0.0_c_float, next_value))
      end do
    end do

    field%current = field%next
  end subroutine step_field_simulation

end module field_simulation
