! Main application loop that coordinates scene generation, simulation,
! interactive controls, and the two-pass renderer.
program harmonic_relic_foundry
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
  integer(c_int) :: substep_count
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
  character(len=256) :: status_line
  type(camera_state) :: camera
  type(relic_control_state) :: controls
  type(platform_input_state) :: input_state
  type(relic_scene_state) :: scene
  type(field_simulation_state) :: resonance_field

  if (.not. init_platform_gl(window_width, window_height, "Harmonic Relic Foundry")) then
    error stop "Failed to initialize GLFW/OpenGL platform bridge."
  end if

  call initialize_camera_state(camera)
  call initialize_relic_controls(initial_relic_seed, controls)
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
      call platform_gl_request_capture("captures")
      print *, "Capture requested. Saving next frame to captures/."
    end if

    substep_count = 0_c_int
    do while (simulation_accumulator >= fixed_timestep .and. substep_count < 4_c_int)
      call step_field_simulation(resonance_field, scene, real(fixed_timestep, c_float))
      simulation_accumulator = simulation_accumulator - fixed_timestep
      substep_count = substep_count + 1_c_int
    end do

    call platform_gl_set_field_texture(resonance_field%width, resonance_field%height, resonance_field%current)
    elapsed_time = current_time
    call platform_gl_render_frame(real(elapsed_time, c_float))
    call platform_gl_swap_buffers()
  end do

  call shutdown_platform_gl()
  print *, "Shutdown complete."

contains

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
