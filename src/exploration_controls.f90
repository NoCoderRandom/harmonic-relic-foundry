! Centralized exploration state and input mapping for camera motion,
! live relic variation, and lightweight status reporting.
module exploration_controls
  use, intrinsic :: iso_c_binding, only: c_float, c_int
  use :: platform_gl, only: platform_input_state
  implicit none
  private

  public :: camera_state
  public :: relic_control_state
  public :: initialize_camera_state
  public :: initialize_relic_controls
  public :: apply_input_to_exploration
  public :: build_status_line
  public :: print_controls_help
  public :: print_status_line

  type :: camera_state
    real(c_float) :: position_x = 0.50_c_float
    real(c_float) :: position_y = 0.54_c_float
    real(c_float) :: position_z = -1.15_c_float
    real(c_float) :: yaw = 0.0_c_float
    real(c_float) :: pitch = 0.0_c_float
    real(c_float) :: fov_degrees = 55.0_c_float
  end type camera_state

  type :: relic_control_state
    integer(c_int) :: base_seed = 1847_c_int
    integer(c_int) :: symmetry_offset = 0_c_int
    real(c_float) :: glyph_density_bias = 0.0_c_float
    real(c_float) :: pulse_intensity_scale = 1.0_c_float
    logical :: post_enabled = .true.
  end type relic_control_state

contains

  pure real(c_float) function clamp_range(value, min_value, max_value) result(clamped)
    real(c_float), intent(in) :: value
    real(c_float), intent(in) :: min_value
    real(c_float), intent(in) :: max_value

    clamped = max(min_value, min(max_value, value))
  end function clamp_range

  subroutine initialize_camera_state(camera)
    type(camera_state), intent(out) :: camera

    camera%position_x = 0.50_c_float
    camera%position_y = 0.54_c_float
    camera%position_z = -1.15_c_float
    camera%yaw = 0.0_c_float
    camera%pitch = 0.0_c_float
    camera%fov_degrees = 55.0_c_float
  end subroutine initialize_camera_state

  subroutine initialize_relic_controls(base_seed, controls)
    integer(c_int), intent(in) :: base_seed
    type(relic_control_state), intent(out) :: controls

    controls%base_seed = base_seed
    controls%symmetry_offset = 0_c_int
    controls%glyph_density_bias = 0.0_c_float
    controls%pulse_intensity_scale = 1.0_c_float
    controls%post_enabled = .true.
  end subroutine initialize_relic_controls

  subroutine apply_input_to_exploration( &
    camera, controls, input_state, dt, scene_dirty, title_dirty, state_requested, capture_requested &
  )
    type(camera_state), intent(inout) :: camera
    type(relic_control_state), intent(inout) :: controls
    type(platform_input_state), intent(in) :: input_state
    real(c_float), intent(in) :: dt
    logical, intent(out) :: scene_dirty
    logical, intent(out) :: title_dirty
    logical, intent(out) :: state_requested
    logical, intent(out) :: capture_requested
    real(c_float) :: clamped_dt
    real(c_float) :: forward_x
    real(c_float) :: forward_y
    real(c_float) :: forward_z
    real(c_float) :: right_x
    real(c_float) :: right_z
    real(c_float) :: movement_x
    real(c_float) :: movement_y
    real(c_float) :: movement_z
    real(c_float) :: previous_x
    real(c_float) :: previous_y
    real(c_float) :: previous_z
    real(c_float) :: previous_yaw
    real(c_float) :: previous_pitch
    real(c_float) :: previous_fov
    real(c_float), parameter :: move_speed = 0.68_c_float
    real(c_float), parameter :: orbit_speed = 1.70_c_float
    real(c_float), parameter :: mouse_sensitivity = 0.0042_c_float
    real(c_float), parameter :: zoom_speed = 32.0_c_float

    clamped_dt = min(max(dt, 0.0_c_float), 0.05_c_float)
    scene_dirty = .false.
    title_dirty = .false.
    state_requested = (input_state%state_requested /= 0_c_int)
    capture_requested = (input_state%capture_requested /= 0_c_int)

    previous_x = camera%position_x
    previous_y = camera%position_y
    previous_z = camera%position_z
    previous_yaw = camera%yaw
    previous_pitch = camera%pitch
    previous_fov = camera%fov_degrees

    camera%yaw = camera%yaw + input_state%orbit_x * orbit_speed * clamped_dt + &
      input_state%mouse_dx * mouse_sensitivity
    camera%pitch = clamp_range( &
      camera%pitch + input_state%orbit_y * orbit_speed * clamped_dt - input_state%mouse_dy * mouse_sensitivity, &
      -1.10_c_float, &
      1.10_c_float &
    )
    camera%fov_degrees = clamp_range( &
      camera%fov_degrees - input_state%scroll_delta * 3.5_c_float - input_state%zoom_axis * zoom_speed * clamped_dt, &
      24.0_c_float, &
      90.0_c_float &
    )

    forward_x = sin(camera%yaw) * cos(camera%pitch)
    forward_y = sin(camera%pitch)
    forward_z = cos(camera%yaw) * cos(camera%pitch)
    right_x = cos(camera%yaw)
    right_z = -sin(camera%yaw)

    movement_x = (input_state%move_x * right_x + input_state%move_z * forward_x) * move_speed * clamped_dt
    movement_y = (input_state%move_y + input_state%move_z * forward_y) * move_speed * clamped_dt
    movement_z = (input_state%move_z * forward_z + input_state%move_x * right_z) * move_speed * clamped_dt

    camera%position_x = clamp_range(camera%position_x + movement_x, -0.35_c_float, 1.35_c_float)
    camera%position_y = clamp_range(camera%position_y + movement_y, -0.15_c_float, 1.25_c_float)
    camera%position_z = clamp_range(camera%position_z + movement_z, -2.60_c_float, -0.25_c_float)

    if (input_state%seed_step /= 0_c_int) then
      controls%base_seed = controls%base_seed + input_state%seed_step
      scene_dirty = .true.
      title_dirty = .true.
      state_requested = .true.
    end if

    if (input_state%symmetry_step /= 0_c_int) then
      controls%symmetry_offset = max(-4_c_int, min(4_c_int, controls%symmetry_offset + input_state%symmetry_step))
      scene_dirty = .true.
      title_dirty = .true.
      state_requested = .true.
    end if

    if (input_state%glyph_step /= 0_c_int) then
      controls%glyph_density_bias = clamp_range( &
        controls%glyph_density_bias + 0.05_c_float * real(input_state%glyph_step, c_float), &
        -0.45_c_float, &
        0.45_c_float &
      )
      scene_dirty = .true.
      title_dirty = .true.
      state_requested = .true.
    end if

    if (input_state%pulse_step /= 0_c_int) then
      controls%pulse_intensity_scale = clamp_range( &
        controls%pulse_intensity_scale + 0.10_c_float * real(input_state%pulse_step, c_float), &
        0.25_c_float, &
        2.50_c_float &
      )
      scene_dirty = .true.
      title_dirty = .true.
      state_requested = .true.
    end if

    if (input_state%post_toggle /= 0_c_int) then
      controls%post_enabled = .not. controls%post_enabled
      title_dirty = .true.
      state_requested = .true.
    end if

    if (abs(camera%position_x - previous_x) > 1.0e-5_c_float .or. &
        abs(camera%position_y - previous_y) > 1.0e-5_c_float .or. &
        abs(camera%position_z - previous_z) > 1.0e-5_c_float .or. &
        abs(camera%yaw - previous_yaw) > 1.0e-5_c_float .or. &
        abs(camera%pitch - previous_pitch) > 1.0e-5_c_float .or. &
        abs(camera%fov_degrees - previous_fov) > 1.0e-5_c_float) then
      title_dirty = .true.
    end if
  end subroutine apply_input_to_exploration

  subroutine build_status_line(camera, controls, status_line)
    type(camera_state), intent(in) :: camera
    type(relic_control_state), intent(in) :: controls
    character(len=*), intent(out) :: status_line

    write( &
      status_line, &
      '(A,I0,A,I0,A,F5.2,A,F5.2,A,F5.1,A,A)' &
    ) &
      "Harmonic Relic Foundry | Seed ", controls%base_seed, &
      " | Sym ", controls%symmetry_offset, &
      " | Glyph ", controls%glyph_density_bias, &
      " | Pulse ", controls%pulse_intensity_scale, &
      " | FOV ", camera%fov_degrees, &
      " | Post ", merge("On ", "Off", controls%post_enabled)
  end subroutine build_status_line

  subroutine print_controls_help()
    print *, "Controls:"
    print *, "  Move: W A S D Q E"
    print *, "  Look: Left mouse drag or arrow keys"
    print *, "  Zoom/FOV: Mouse wheel or Z/X"
    print *, "  Seed: 1/2  Symmetry: 3/4  Glyph: 5/6  Pulse: 7/8"
    print *, "  Toggle post: O  Capture still: C"
    print *, "  Print state: P"
  end subroutine print_controls_help

  subroutine print_status_line(camera, controls)
    type(camera_state), intent(in) :: camera
    type(relic_control_state), intent(in) :: controls

    write(*,'(A,I0,A,I0,A,F5.2,A,F5.2,A,F5.1,A,L1)') &
      "State | seed=", controls%base_seed, &
      " sym=", controls%symmetry_offset, &
      " glyph=", controls%glyph_density_bias, &
      " pulse=", controls%pulse_intensity_scale, &
      " fov=", camera%fov_degrees, &
      " post=", controls%post_enabled
    write(*,'(A,3(F6.2,1X),A,2(F6.2,1X))') &
      "Camera | pos=", camera%position_x, camera%position_y, camera%position_z, &
      " orient=", camera%yaw, camera%pitch
  end subroutine print_status_line

end module exploration_controls
