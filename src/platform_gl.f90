! Thin Fortran bindings over the GLFW/OpenGL bridge implemented in C.
module platform_gl
  use, intrinsic :: iso_c_binding, only: c_char, c_double, c_float, c_int, c_null_char
  implicit none
  private

  type, bind(C), public :: platform_input_state
    real(c_float) :: move_x = 0.0_c_float
    real(c_float) :: move_y = 0.0_c_float
    real(c_float) :: move_z = 0.0_c_float
    real(c_float) :: orbit_x = 0.0_c_float
    real(c_float) :: orbit_y = 0.0_c_float
    real(c_float) :: mouse_dx = 0.0_c_float
    real(c_float) :: mouse_dy = 0.0_c_float
    real(c_float) :: zoom_axis = 0.0_c_float
    real(c_float) :: scroll_delta = 0.0_c_float
    integer(c_int) :: seed_step = 0_c_int
    integer(c_int) :: symmetry_step = 0_c_int
    integer(c_int) :: glyph_step = 0_c_int
    integer(c_int) :: pulse_step = 0_c_int
    integer(c_int) :: post_toggle = 0_c_int
    integer(c_int) :: capture_requested = 0_c_int
    integer(c_int) :: state_requested = 0_c_int
  end type platform_input_state

  public :: init_platform_gl
  public :: platform_gl_get_input_state
  public :: platform_gl_set_camera_state
  public :: platform_gl_set_post_parameters
  public :: platform_gl_request_capture
  public :: platform_gl_set_field_texture
  public :: platform_gl_set_relic_parameters
  public :: platform_gl_get_time
  public :: platform_gl_set_window_title
  public :: platform_gl_should_close
  public :: platform_gl_render_frame
  public :: platform_gl_poll_events
  public :: platform_gl_swap_buffers
  public :: shutdown_platform_gl

  interface
    function hrf_gl_init(width, height, title) bind(C, name="hrf_gl_init") result(status)
      import :: c_char, c_int
      integer(c_int), value :: width
      integer(c_int), value :: height
      character(kind=c_char), dimension(*) :: title
      integer(c_int) :: status
    end function hrf_gl_init

    function hrf_gl_should_close() bind(C, name="hrf_gl_should_close") result(status)
      import :: c_int
      integer(c_int) :: status
    end function hrf_gl_should_close

    function hrf_gl_get_time() bind(C, name="hrf_gl_get_time") result(time_seconds)
      import :: c_double
      real(c_double) :: time_seconds
    end function hrf_gl_get_time

    subroutine hrf_gl_get_input_state(input_state) bind(C, name="hrf_gl_get_input_state")
      import :: platform_input_state
      type(platform_input_state), intent(out) :: input_state
    end subroutine hrf_gl_get_input_state

    subroutine hrf_gl_set_camera_state( &
      position_x, position_y, position_z, yaw, pitch, fov_degrees &
    ) bind(C, name="hrf_gl_set_camera_state")
      import :: c_float
      real(c_float), value :: position_x
      real(c_float), value :: position_y
      real(c_float), value :: position_z
      real(c_float), value :: yaw
      real(c_float), value :: pitch
      real(c_float), value :: fov_degrees
    end subroutine hrf_gl_set_camera_state

    subroutine hrf_gl_set_post_parameters( &
      enabled, bloom_strength, vignette_strength, exposure &
    ) bind(C, name="hrf_gl_set_post_parameters")
      import :: c_float, c_int
      integer(c_int), value :: enabled
      real(c_float), value :: bloom_strength
      real(c_float), value :: vignette_strength
      real(c_float), value :: exposure
    end subroutine hrf_gl_set_post_parameters

    subroutine hrf_gl_request_capture(output_dir) bind(C, name="hrf_gl_request_capture")
      import :: c_char
      character(kind=c_char), dimension(*) :: output_dir
    end subroutine hrf_gl_request_capture

    subroutine hrf_gl_set_field_texture(width, height, field_data) bind(C, name="hrf_gl_set_field_texture")
      import :: c_float, c_int
      integer(c_int), value :: width
      integer(c_int), value :: height
      real(c_float), intent(in) :: field_data(*)
    end subroutine hrf_gl_set_field_texture

    subroutine hrf_gl_set_relic_parameters( &
      dominant_index, &
      descriptor_count, &
      symmetry, &
      ring_count, &
      glyph_density, &
      fracture_amount, &
      emissive_hue_bias, &
      pulse_speed, &
      pulse_intensity, &
      center_x, &
      center_y, &
      region_scale_x, &
      region_scale_y, &
      region_rotation, &
      layer_depth, &
      composition_weight, &
      overlap_softness, &
      pulse_phase &
    ) bind(C, name="hrf_gl_set_relic_parameters")
      import :: c_float, c_int
      integer(c_int), value :: dominant_index
      integer(c_int), value :: descriptor_count
      real(c_float), intent(in) :: symmetry(*)
      real(c_float), intent(in) :: ring_count(*)
      real(c_float), intent(in) :: glyph_density(*)
      real(c_float), intent(in) :: fracture_amount(*)
      real(c_float), intent(in) :: emissive_hue_bias(*)
      real(c_float), intent(in) :: pulse_speed(*)
      real(c_float), intent(in) :: pulse_intensity(*)
      real(c_float), intent(in) :: center_x(*)
      real(c_float), intent(in) :: center_y(*)
      real(c_float), intent(in) :: region_scale_x(*)
      real(c_float), intent(in) :: region_scale_y(*)
      real(c_float), intent(in) :: region_rotation(*)
      real(c_float), intent(in) :: layer_depth(*)
      real(c_float), intent(in) :: composition_weight(*)
      real(c_float), intent(in) :: overlap_softness(*)
      real(c_float), intent(in) :: pulse_phase(*)
    end subroutine hrf_gl_set_relic_parameters

    subroutine hrf_gl_set_window_title(title) bind(C, name="hrf_gl_set_window_title")
      import :: c_char
      character(kind=c_char), dimension(*) :: title
    end subroutine hrf_gl_set_window_title

    subroutine hrf_gl_render_frame(time_seconds) bind(C, name="hrf_gl_render_frame")
      import :: c_float
      real(c_float), value :: time_seconds
    end subroutine hrf_gl_render_frame

    subroutine hrf_gl_poll_events() bind(C, name="hrf_gl_poll_events")
    end subroutine hrf_gl_poll_events

    subroutine hrf_gl_swap_buffers() bind(C, name="hrf_gl_swap_buffers")
    end subroutine hrf_gl_swap_buffers

    subroutine hrf_gl_shutdown() bind(C, name="hrf_gl_shutdown")
    end subroutine hrf_gl_shutdown
  end interface

contains

  function init_platform_gl(width, height, title) result(ok)
    integer(c_int), intent(in) :: width
    integer(c_int), intent(in) :: height
    character(len=*), intent(in) :: title
    logical :: ok
    character(kind=c_char), allocatable :: c_title(:)
    integer :: i
    integer :: title_length

    title_length = len_trim(title)
    allocate(c_title(title_length + 1))

    do i = 1, title_length
      c_title(i) = title(i:i)
    end do
    c_title(title_length + 1) = c_null_char

    ok = (hrf_gl_init(width, height, c_title) /= 0_c_int)
  end function init_platform_gl

  function platform_gl_should_close() result(should_close)
    logical :: should_close

    should_close = (hrf_gl_should_close() /= 0_c_int)
  end function platform_gl_should_close

  function platform_gl_get_time() result(time_seconds)
    real(c_double) :: time_seconds

    time_seconds = hrf_gl_get_time()
  end function platform_gl_get_time

  subroutine platform_gl_get_input_state(input_state)
    type(platform_input_state), intent(out) :: input_state

    call hrf_gl_get_input_state(input_state)
  end subroutine platform_gl_get_input_state

  subroutine platform_gl_set_camera_state(position_x, position_y, position_z, yaw, pitch, fov_degrees)
    real(c_float), intent(in) :: position_x
    real(c_float), intent(in) :: position_y
    real(c_float), intent(in) :: position_z
    real(c_float), intent(in) :: yaw
    real(c_float), intent(in) :: pitch
    real(c_float), intent(in) :: fov_degrees

    call hrf_gl_set_camera_state(position_x, position_y, position_z, yaw, pitch, fov_degrees)
  end subroutine platform_gl_set_camera_state

  subroutine platform_gl_set_post_parameters(enabled, bloom_strength, vignette_strength, exposure)
    logical, intent(in) :: enabled
    real(c_float), intent(in) :: bloom_strength
    real(c_float), intent(in) :: vignette_strength
    real(c_float), intent(in) :: exposure

    call hrf_gl_set_post_parameters( &
      merge(1_c_int, 0_c_int, enabled), &
      bloom_strength, &
      vignette_strength, &
      exposure &
    )
  end subroutine platform_gl_set_post_parameters

  subroutine platform_gl_request_capture(output_dir)
    character(len=*), intent(in) :: output_dir
    character(kind=c_char), allocatable :: c_output_dir(:)
    integer :: i
    integer :: output_length

    output_length = len_trim(output_dir)
    allocate(c_output_dir(output_length + 1))

    do i = 1, output_length
      c_output_dir(i) = output_dir(i:i)
    end do
    c_output_dir(output_length + 1) = c_null_char

    call hrf_gl_request_capture(c_output_dir)
  end subroutine platform_gl_request_capture

  subroutine platform_gl_set_field_texture(width, height, field_data)
    integer(c_int), intent(in) :: width
    integer(c_int), intent(in) :: height
    real(c_float), intent(in) :: field_data(:)

    call hrf_gl_set_field_texture(width, height, field_data)
  end subroutine platform_gl_set_field_texture

  subroutine platform_gl_set_relic_parameters( &
    dominant_index, &
    descriptor_count, &
    symmetry, &
    ring_count, &
    glyph_density, &
    fracture_amount, &
    emissive_hue_bias, &
    pulse_speed, &
    pulse_intensity, &
    center_x, &
    center_y, &
    region_scale_x, &
    region_scale_y, &
    region_rotation, &
    layer_depth, &
    composition_weight, &
    overlap_softness, &
    pulse_phase &
  )
    integer(c_int), intent(in) :: dominant_index
    integer(c_int), intent(in) :: descriptor_count
    real(c_float), intent(in) :: symmetry(:)
    real(c_float), intent(in) :: ring_count(:)
    real(c_float), intent(in) :: glyph_density(:)
    real(c_float), intent(in) :: fracture_amount(:)
    real(c_float), intent(in) :: emissive_hue_bias(:)
    real(c_float), intent(in) :: pulse_speed(:)
    real(c_float), intent(in) :: pulse_intensity(:)
    real(c_float), intent(in) :: center_x(:)
    real(c_float), intent(in) :: center_y(:)
    real(c_float), intent(in) :: region_scale_x(:)
    real(c_float), intent(in) :: region_scale_y(:)
    real(c_float), intent(in) :: region_rotation(:)
    real(c_float), intent(in) :: layer_depth(:)
    real(c_float), intent(in) :: composition_weight(:)
    real(c_float), intent(in) :: overlap_softness(:)
    real(c_float), intent(in) :: pulse_phase(:)

    call hrf_gl_set_relic_parameters( &
      dominant_index, &
      descriptor_count, &
      symmetry, &
      ring_count, &
      glyph_density, &
      fracture_amount, &
      emissive_hue_bias, &
      pulse_speed, &
      pulse_intensity, &
      center_x, &
      center_y, &
      region_scale_x, &
      region_scale_y, &
      region_rotation, &
      layer_depth, &
      composition_weight, &
      overlap_softness, &
      pulse_phase &
    )
  end subroutine platform_gl_set_relic_parameters

  subroutine platform_gl_set_window_title(title)
    character(len=*), intent(in) :: title
    character(kind=c_char), allocatable :: c_title(:)
    integer :: i
    integer :: title_length

    title_length = len_trim(title)
    allocate(c_title(title_length + 1))

    do i = 1, title_length
      c_title(i) = title(i:i)
    end do
    c_title(title_length + 1) = c_null_char

    call hrf_gl_set_window_title(c_title)
  end subroutine platform_gl_set_window_title

  subroutine platform_gl_render_frame(time_seconds)
    real(c_float), intent(in) :: time_seconds

    call hrf_gl_render_frame(time_seconds)
  end subroutine platform_gl_render_frame

  subroutine platform_gl_poll_events()
    call hrf_gl_poll_events()
  end subroutine platform_gl_poll_events

  subroutine platform_gl_swap_buffers()
    call hrf_gl_swap_buffers()
  end subroutine platform_gl_swap_buffers

  subroutine shutdown_platform_gl()
    call hrf_gl_shutdown()
  end subroutine shutdown_platform_gl

end module platform_gl
