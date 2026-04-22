! Main application loop that coordinates scene generation, simulation,
! interactive controls, and the two-pass renderer.
program harmonic_relic_foundry
  use, intrinsic :: iso_fortran_env, only: error_unit
  use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int
  use :: exploration_controls, only: camera_state, relic_control_state, apply_input_to_exploration, &
    build_status_line, initialize_camera_state, initialize_relic_controls, print_controls_help, print_status_line
  use :: field_simulation, only: field_simulation_state, initialize_field_simulation, step_field_simulation
  use :: platform_gl
  use :: relic_state, only: apply_scene_variation, initialize_relic_scene, relic_scene_state
  implicit none

  integer(c_int), parameter :: window_width = 1280_c_int
  integer(c_int), parameter :: window_height = 720_c_int
  integer(c_int), parameter :: field_width = 192_c_int
  integer(c_int), parameter :: field_height = 192_c_int
  integer(c_int), parameter :: initial_relic_seed = 1847_c_int
  real(c_float), parameter :: bloom_strength = 0.52_c_float
  real(c_float), parameter :: vignette_strength = 0.78_c_float
  real(c_float), parameter :: presentation_exposure = 1.08_c_float
  type :: runtime_options
    integer(c_int) :: seed = initial_relic_seed
    integer(c_int) :: symmetry_offset = 0_c_int
    integer(c_int) :: frames_before_capture = 24_c_int
    real(c_float) :: glyph_density_bias = 0.0_c_float
    real(c_float) :: pulse_intensity_scale = 1.0_c_float
    real(c_float) :: position_x = 0.50_c_float
    real(c_float) :: position_y = 0.54_c_float
    real(c_float) :: position_z = -1.15_c_float
    real(c_float) :: yaw = 0.0_c_float
    real(c_float) :: pitch = 0.0_c_float
    real(c_float) :: fov_degrees = 55.0_c_float
    logical :: post_enabled = .true.
    logical :: auto_capture = .false.
    logical :: exit_after_capture = .false.
    character(len=256) :: capture_dir = "captures"
  end type runtime_options
  integer(c_int) :: substep_count
  integer(c_int) :: rendered_frame_count
  real(c_double) :: current_time
  real(c_double) :: elapsed_time
  real(c_double) :: frame_dt
  real(c_double) :: previous_time
  real(c_double) :: simulation_accumulator
  real(c_double), parameter :: fixed_timestep = 1.0d0 / 60.0d0
  logical :: scene_dirty
  logical :: title_dirty
  logical :: state_requested
  logical :: capture_requested
  logical :: auto_capture_pending
  logical :: exit_after_presenting_capture
  character(len=256) :: status_line
  type(camera_state) :: camera
  type(relic_control_state) :: controls
  type(platform_input_state) :: input_state
  type(relic_scene_state) :: scene
  type(field_simulation_state) :: resonance_field
  type(runtime_options) :: options

  call parse_runtime_options(options)

  if (.not. init_platform_gl(window_width, window_height, "Harmonic Relic Foundry")) then
    error stop "Failed to initialize GLFW/OpenGL platform bridge."
  end if

  call initialize_camera_state(camera)
  call initialize_relic_controls(options%seed, controls)
  camera%position_x = options%position_x
  camera%position_y = options%position_y
  camera%position_z = options%position_z
  camera%yaw = options%yaw
  camera%pitch = options%pitch
  camera%fov_degrees = options%fov_degrees
  controls%symmetry_offset = options%symmetry_offset
  controls%glyph_density_bias = options%glyph_density_bias
  controls%pulse_intensity_scale = options%pulse_intensity_scale
  controls%post_enabled = options%post_enabled
  call rebuild_scene()
  call platform_gl_set_camera_state( &
    camera%position_x, &
    camera%position_y, &
    camera%position_z, &
    camera%yaw, &
    camera%pitch, &
    camera%fov_degrees &
  )
  call build_status_line(camera, controls, status_line)
  call platform_gl_set_window_title(status_line)
  call platform_gl_set_post_parameters(controls%post_enabled, bloom_strength, vignette_strength, presentation_exposure)

  previous_time = platform_gl_get_time()
  simulation_accumulator = 0.0d0
  rendered_frame_count = 0_c_int
  auto_capture_pending = options%auto_capture
  exit_after_presenting_capture = .false.

  print *, "Window created. Entering shader render loop."
  print *, "Relic seed:", controls%base_seed
  print *, "Dominant relic slot:", scene%dominant_index
  print *, "Dominant descriptor symmetry/rings:", &
    scene%descriptors(scene%dominant_index)%symmetry_count, &
    scene%descriptors(scene%dominant_index)%ring_count
  print *, "Field resolution:", resonance_field%width, "x", resonance_field%height
  call print_controls_help()
  call print_status_line(camera, controls)

  do while (.not. platform_gl_should_close())
    current_time = platform_gl_get_time()
    frame_dt = min(max(current_time - previous_time, 0.0d0), 0.1d0)
    previous_time = current_time
    simulation_accumulator = simulation_accumulator + frame_dt

    call platform_gl_poll_events()
    call platform_gl_get_input_state(input_state)
    call apply_input_to_exploration( &
      camera, &
      controls, &
      input_state, &
      real(frame_dt, c_float), &
      scene_dirty, &
      title_dirty, &
      state_requested, &
      capture_requested &
    )

    if (scene_dirty) then
      call rebuild_scene()
      title_dirty = .true.
    end if

    if (title_dirty) then
      call build_status_line(camera, controls, status_line)
      call platform_gl_set_window_title(status_line)
    end if

    if (state_requested) then
      call print_status_line(camera, controls)
    end if

    call platform_gl_set_camera_state( &
      camera%position_x, &
      camera%position_y, &
      camera%position_z, &
      camera%yaw, &
      camera%pitch, &
      camera%fov_degrees &
    )
    call platform_gl_set_post_parameters(controls%post_enabled, bloom_strength, vignette_strength, presentation_exposure)

    if (capture_requested) then
      call platform_gl_request_capture(trim(options%capture_dir))
      print *, "Capture requested. Saving next frame to ", trim(options%capture_dir), "/."
    end if

    substep_count = 0_c_int
    do while (simulation_accumulator >= fixed_timestep .and. substep_count < 4_c_int)
      call step_field_simulation(resonance_field, scene, real(fixed_timestep, c_float))
      simulation_accumulator = simulation_accumulator - fixed_timestep
      substep_count = substep_count + 1_c_int
    end do

    if (auto_capture_pending .and. rendered_frame_count >= options%frames_before_capture) then
      call platform_gl_request_capture(trim(options%capture_dir))
      auto_capture_pending = .false.
      exit_after_presenting_capture = options%exit_after_capture
      print *, "Auto capture requested. Saving next frame to ", trim(options%capture_dir), "/."
    end if

    call platform_gl_set_field_texture(resonance_field%width, resonance_field%height, resonance_field%current)
    elapsed_time = current_time
    call platform_gl_render_frame(real(elapsed_time, c_float))
    call platform_gl_swap_buffers()
    rendered_frame_count = rendered_frame_count + 1_c_int

    if (exit_after_presenting_capture) exit
  end do

  call shutdown_platform_gl()
  print *, "Shutdown complete."

contains

  subroutine parse_runtime_options(options)
    type(runtime_options), intent(inout) :: options
    integer :: arg_count
    integer :: index
    character(len=256) :: arg

    arg_count = command_argument_count()
    index = 1

    do while (index <= arg_count)
      call get_command_argument(index, arg)

      select case (trim(arg))
      case ("--seed")
        call read_next_integer(arg_count, index, options%seed, "--seed")
      case ("--symmetry-offset")
        call read_next_integer(arg_count, index, options%symmetry_offset, "--symmetry-offset")
      case ("--glyph-bias")
        call read_next_real(arg_count, index, options%glyph_density_bias, "--glyph-bias")
      case ("--pulse-scale")
        call read_next_real(arg_count, index, options%pulse_intensity_scale, "--pulse-scale")
      case ("--position")
        call read_next_real(arg_count, index, options%position_x, "--position x")
        call read_next_real(arg_count, index, options%position_y, "--position y")
        call read_next_real(arg_count, index, options%position_z, "--position z")
      case ("--orientation")
        call read_next_real(arg_count, index, options%yaw, "--orientation yaw")
        call read_next_real(arg_count, index, options%pitch, "--orientation pitch")
      case ("--camera")
        call read_next_real(arg_count, index, options%position_x, "--camera x")
        call read_next_real(arg_count, index, options%position_y, "--camera y")
        call read_next_real(arg_count, index, options%position_z, "--camera z")
        call read_next_real(arg_count, index, options%yaw, "--camera yaw")
        call read_next_real(arg_count, index, options%pitch, "--camera pitch")
        call read_next_real(arg_count, index, options%fov_degrees, "--camera fov")
      case ("--fov")
        call read_next_real(arg_count, index, options%fov_degrees, "--fov")
      case ("--capture-dir")
        call read_next_string(arg_count, index, options%capture_dir, "--capture-dir")
      case ("--frames-before-capture")
        call read_next_integer(arg_count, index, options%frames_before_capture, "--frames-before-capture")
      case ("--auto-capture")
        options%auto_capture = .true.
      case ("--exit-after-capture")
        options%auto_capture = .true.
        options%exit_after_capture = .true.
      case ("--no-post")
        options%post_enabled = .false.
      case ("--post")
        call read_next_logical(arg_count, index, options%post_enabled, "--post")
      case ("--help", "-h")
        call print_usage_and_exit()
      case default
        write(error_unit, '(A)') "Unknown argument: " // trim(arg)
        call print_usage_and_exit(.true.)
      end select

      index = index + 1
    end do

    options%symmetry_offset = max(-4_c_int, min(4_c_int, options%symmetry_offset))
    options%glyph_density_bias = max(-0.45_c_float, min(0.45_c_float, options%glyph_density_bias))
    options%pulse_intensity_scale = max(0.25_c_float, min(2.50_c_float, options%pulse_intensity_scale))
    options%fov_degrees = max(24.0_c_float, min(90.0_c_float, options%fov_degrees))
    options%position_x = max(-0.35_c_float, min(1.35_c_float, options%position_x))
    options%position_y = max(-0.15_c_float, min(1.25_c_float, options%position_y))
    options%position_z = max(-2.60_c_float, min(-0.25_c_float, options%position_z))
    options%pitch = max(-1.10_c_float, min(1.10_c_float, options%pitch))

    if (options%frames_before_capture < 0_c_int) then
      write(error_unit, '(A)') "--frames-before-capture must be zero or greater."
      error stop 1
    end if
  end subroutine parse_runtime_options

  subroutine read_next_integer(arg_count, index, value, option_name)
    integer, intent(in) :: arg_count
    integer, intent(inout) :: index
    integer(c_int), intent(out) :: value
    character(len=*), intent(in) :: option_name
    character(len=256) :: next_arg
    integer :: io_status

    call require_next_argument(arg_count, index, option_name)
    call get_command_argument(index, next_arg)
    read(next_arg, *, iostat=io_status) value
    if (io_status /= 0) then
      write(error_unit, '(A)') "Invalid integer for " // trim(option_name) // ": " // trim(next_arg)
      error stop 1
    end if
  end subroutine read_next_integer

  subroutine read_next_real(arg_count, index, value, option_name)
    integer, intent(in) :: arg_count
    integer, intent(inout) :: index
    real(c_float), intent(out) :: value
    character(len=*), intent(in) :: option_name
    character(len=256) :: next_arg
    integer :: io_status

    call require_next_argument(arg_count, index, option_name)
    call get_command_argument(index, next_arg)
    read(next_arg, *, iostat=io_status) value
    if (io_status /= 0) then
      write(error_unit, '(A)') "Invalid real value for " // trim(option_name) // ": " // trim(next_arg)
      error stop 1
    end if
  end subroutine read_next_real

  subroutine read_next_string(arg_count, index, value, option_name)
    integer, intent(in) :: arg_count
    integer, intent(inout) :: index
    character(len=*), intent(out) :: value
    character(len=*), intent(in) :: option_name
    character(len=256) :: next_arg

    call require_next_argument(arg_count, index, option_name)
    call get_command_argument(index, next_arg)
    value = trim(next_arg)
  end subroutine read_next_string

  subroutine read_next_logical(arg_count, index, value, option_name)
    integer, intent(in) :: arg_count
    integer, intent(inout) :: index
    logical, intent(out) :: value
    character(len=*), intent(in) :: option_name
    character(len=256) :: next_arg

    call require_next_argument(arg_count, index, option_name)
    call get_command_argument(index, next_arg)

    select case (trim(next_arg))
    case ("on", "true", "1")
      value = .true.
    case ("off", "false", "0")
      value = .false.
    case default
      write(error_unit, '(A)') "Invalid logical value for " // trim(option_name) // ": " // trim(next_arg)
      error stop 1
    end select
  end subroutine read_next_logical

  subroutine require_next_argument(arg_count, index, option_name)
    integer, intent(in) :: arg_count
    integer, intent(inout) :: index
    character(len=*), intent(in) :: option_name

    index = index + 1
    if (index > arg_count) then
      write(error_unit, '(A)') "Missing value for " // trim(option_name)
      error stop 1
    end if
  end subroutine require_next_argument

  subroutine print_usage_and_exit(has_error)
    logical, intent(in), optional :: has_error
    logical :: exit_with_error

    exit_with_error = .false.
    if (present(has_error)) exit_with_error = has_error

    write(*, '(A)') "Usage: ./build/harmonic_relic_foundry [options]"
    write(*, '(A)') "  --seed <int>"
    write(*, '(A)') "  --symmetry-offset <int>"
    write(*, '(A)') "  --glyph-bias <real>"
    write(*, '(A)') "  --pulse-scale <real>"
    write(*, '(A)') "  --position <x> <y> <z>"
    write(*, '(A)') "  --orientation <yaw> <pitch>"
    write(*, '(A)') "  --camera <x> <y> <z> <yaw> <pitch> <fov>"
    write(*, '(A)') "  --fov <real>"
    write(*, '(A)') "  --post <on|off> | --no-post"
    write(*, '(A)') "  --capture-dir <path>"
    write(*, '(A)') "  --frames-before-capture <int>"
    write(*, '(A)') "  --auto-capture"
    write(*, '(A)') "  --exit-after-capture"

    if (exit_with_error) then
      error stop 1
    end if

    stop
  end subroutine print_usage_and_exit

  subroutine rebuild_scene()
    call initialize_relic_scene(controls%base_seed, scene)
    call apply_scene_variation( &
      scene, &
      controls%symmetry_offset, &
      controls%glyph_density_bias, &
      controls%pulse_intensity_scale &
    )
    call initialize_field_simulation(scene, field_width, field_height, resonance_field)
    call platform_gl_set_relic_parameters( &
      scene%dominant_index - 1_c_int, &
      scene%descriptor_count, &
      scene%symmetry, &
      scene%ring_count, &
      scene%glyph_density, &
      scene%fracture_amount, &
      scene%emissive_hue_bias, &
      scene%pulse_speed, &
      scene%pulse_intensity, &
      scene%center_x, &
      scene%center_y, &
      scene%region_scale_x, &
      scene%region_scale_y, &
      scene%region_rotation, &
      scene%layer_depth, &
      scene%composition_weight, &
      scene%overlap_softness, &
      scene%pulse_phase &
    )
    call platform_gl_set_field_texture(resonance_field%width, resonance_field%height, resonance_field%current)
  end subroutine rebuild_scene

end program harmonic_relic_foundry
