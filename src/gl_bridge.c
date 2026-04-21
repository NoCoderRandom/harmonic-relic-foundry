/*
 * GLFW/OpenGL bridge for window creation, input polling, scene rendering,
 * post-processing, and simple still-image capture.
 */
#define GLFW_INCLUDE_NONE
#include <GL/gl.h>
#include <GL/glcorearb.h>
#include <GLFW/glfw3.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define HRF_MAX_RELIC_DESCRIPTORS 3
#define HRF_CAPTURE_PATH_MAX 512

static GLFWwindow *g_window = NULL;
static GLuint g_program = 0;
static GLuint g_post_program = 0;
static GLuint g_field_texture = 0;
static GLuint g_scene_color_texture = 0;
static GLuint g_scene_framebuffer = 0;
static GLuint g_vertex_array = 0;
static GLint g_u_field_texture = -1;
static GLint g_u_field_texel_size = -1;
static GLint g_u_resolution = -1;
static GLint g_u_time = -1;
static GLint g_u_relic_count = -1;
static GLint g_u_dominant_index = -1;
static GLint g_u_symmetry = -1;
static GLint g_u_ring_count = -1;
static GLint g_u_glyph_density = -1;
static GLint g_u_fracture_amount = -1;
static GLint g_u_emissive_hue_bias = -1;
static GLint g_u_pulse_speed = -1;
static GLint g_u_pulse_intensity = -1;
static GLint g_u_center_x = -1;
static GLint g_u_center_y = -1;
static GLint g_u_region_scale_x = -1;
static GLint g_u_region_scale_y = -1;
static GLint g_u_region_rotation = -1;
static GLint g_u_layer_depth = -1;
static GLint g_u_composition_weight = -1;
static GLint g_u_overlap_softness = -1;
static GLint g_u_pulse_phase = -1;
static GLint g_u_camera_position = -1;
static GLint g_u_camera_yaw = -1;
static GLint g_u_camera_pitch = -1;
static GLint g_u_camera_fov = -1;
static GLint g_u_post_scene_texture = -1;
static GLint g_u_post_resolution = -1;
static GLint g_u_post_time = -1;
static GLint g_u_post_enabled = -1;
static GLint g_u_post_bloom_strength = -1;
static GLint g_u_post_vignette_strength = -1;
static GLint g_u_post_exposure = -1;

static GLfloat g_relic_symmetry[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_ring_count[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_glyph_density[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_fracture_amount[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_emissive_hue_bias[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_pulse_speed[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_pulse_intensity[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_center_x[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_center_y[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_region_scale_x[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_region_scale_y[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_region_rotation[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_layer_depth[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_composition_weight[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_overlap_softness[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLfloat g_relic_pulse_phase[HRF_MAX_RELIC_DESCRIPTORS] = {0.0f, 0.0f, 0.0f};
static GLint g_relic_count = 0;
static GLint g_dominant_index = 0;
static GLint g_field_width = 0;
static GLint g_field_height = 0;
static GLint g_scene_width = 0;
static GLint g_scene_height = 0;
static GLfloat g_camera_position[3] = {0.5f, 0.54f, -1.15f};
static GLfloat g_camera_yaw = 0.0f;
static GLfloat g_camera_pitch = 0.0f;
static GLfloat g_camera_fov = 55.0f;
static GLint g_post_enabled = 1;
static GLfloat g_post_bloom_strength = 0.52f;
static GLfloat g_post_vignette_strength = 0.78f;
static GLfloat g_post_exposure = 1.08f;
static int g_capture_requested = 0;
static char g_capture_directory[HRF_CAPTURE_PATH_MAX] = "captures";

typedef struct hrf_input_state {
  float move_x;
  float move_y;
  float move_z;
  float orbit_x;
  float orbit_y;
  float mouse_dx;
  float mouse_dy;
  float zoom_axis;
  float scroll_delta;
  int seed_step;
  int symmetry_step;
  int glyph_step;
  int pulse_step;
  int post_toggle;
  int capture_requested;
  int state_requested;
} hrf_input_state;

static int g_prev_key_states[GLFW_KEY_LAST + 1] = {0};
static double g_prev_cursor_x = 0.0;
static double g_prev_cursor_y = 0.0;
static int g_cursor_initialized = 0;
static float g_scroll_delta = 0.0f;

void hrf_gl_shutdown(void);

static void on_scroll(GLFWwindow *window, double xoffset, double yoffset) {
  (void)window;
  (void)xoffset;
  g_scroll_delta += (float)yoffset;
}

static int environment_has_wayland_session(void) {
  const char *wayland_display = getenv("WAYLAND_DISPLAY");
  const char *xdg_session_type = getenv("XDG_SESSION_TYPE");

  if (wayland_display != NULL && wayland_display[0] != '\0') {
    return 1;
  }

  if (xdg_session_type != NULL && strcmp(xdg_session_type, "wayland") == 0) {
    return 1;
  }

  return 0;
}

static int glfw_library_is_x11_only(void) {
  const char *version_string = glfwGetVersionString();

  if (version_string == NULL) {
    return 0;
  }

  return strstr(version_string, " X11 ") != NULL &&
         strstr(version_string, " Wayland ") == NULL;
}

static void print_glfw_backend_hint(const char *error_message) {
  const char *display = getenv("DISPLAY");
  const char *wayland_display = getenv("WAYLAND_DISPLAY");
  const char *xdg_session_type = getenv("XDG_SESSION_TYPE");
  const char *version_string = glfwGetVersionString();

  fprintf(
      stderr,
      "[FAIL] glfwInit failed%s%s\n",
      error_message != NULL ? ": " : ".",
      error_message != NULL ? error_message : "");

  fprintf(
      stderr,
      "[INFO] GLFW build: %s\n",
      version_string != NULL ? version_string : "unknown");
  fprintf(
      stderr,
      "[INFO] Session environment: XDG_SESSION_TYPE=%s WAYLAND_DISPLAY=%s DISPLAY=%s\n",
      xdg_session_type != NULL ? xdg_session_type : "(unset)",
      wayland_display != NULL ? wayland_display : "(unset)",
      display != NULL ? display : "(unset)");

  if (environment_has_wayland_session() && glfw_library_is_x11_only()) {
    fprintf(
        stderr,
        "[FAIL] Wayland session detected, but the installed GLFW library is the X11-only Ubuntu build.\n");
    fprintf(
        stderr,
        "[INFO] Install the Wayland variant of GLFW and rebuild this project.\n");
    fprintf(
        stderr,
        "[INFO] On Ubuntu 24.04 this is typically: sudo apt install libglfw3-wayland libglfw3-dev\n");
  }
}

static PFNGLATTACHSHADERPROC glAttachShaderPtr = NULL;
static PFNGLACTIVETEXTUREPROC glActiveTexturePtr = NULL;
static PFNGLBINDVERTEXARRAYPROC glBindVertexArrayPtr = NULL;
static PFNGLBINDFRAMEBUFFERPROC glBindFramebufferPtr = NULL;
static PFNGLCOMPILESHADERPROC glCompileShaderPtr = NULL;
static PFNGLCREATEPROGRAMPROC glCreateProgramPtr = NULL;
static PFNGLCREATESHADERPROC glCreateShaderPtr = NULL;
static PFNGLCHECKFRAMEBUFFERSTATUSPROC glCheckFramebufferStatusPtr = NULL;
static PFNGLDELETEPROGRAMPROC glDeleteProgramPtr = NULL;
static PFNGLDELETEFRAMEBUFFERSPROC glDeleteFramebuffersPtr = NULL;
static PFNGLDELETESHADERPROC glDeleteShaderPtr = NULL;
static PFNGLDELETEVERTEXARRAYSPROC glDeleteVertexArraysPtr = NULL;
static PFNGLFRAMEBUFFERTEXTURE2DPROC glFramebufferTexture2DPtr = NULL;
static PFNGLGENFRAMEBUFFERSPROC glGenFramebuffersPtr = NULL;
static PFNGLGENVERTEXARRAYSPROC glGenVertexArraysPtr = NULL;
static PFNGLGETPROGRAMINFOLOGPROC glGetProgramInfoLogPtr = NULL;
static PFNGLGETPROGRAMIVPROC glGetProgramivPtr = NULL;
static PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLogPtr = NULL;
static PFNGLGETSHADERIVPROC glGetShaderivPtr = NULL;
static PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocationPtr = NULL;
static PFNGLLINKPROGRAMPROC glLinkProgramPtr = NULL;
static PFNGLSHADERSOURCEPROC glShaderSourcePtr = NULL;
static PFNGLUNIFORM1FVPROC glUniform1fvPtr = NULL;
static PFNGLUNIFORM1IPROC glUniform1iPtr = NULL;
static PFNGLUNIFORM1FPROC glUniform1fPtr = NULL;
static PFNGLUNIFORM2FPROC glUniform2fPtr = NULL;
static PFNGLUNIFORM3FPROC glUniform3fPtr = NULL;
static PFNGLUSEPROGRAMPROC glUseProgramPtr = NULL;

static const char g_vertex_shader_source[] =
    "#version 330 core\n"
    "out vec2 v_uv;\n"
    "\n"
    "void main(void) {\n"
    "  vec2 positions[4] = vec2[](\n"
    "      vec2(-1.0, -1.0),\n"
    "      vec2( 1.0, -1.0),\n"
    "      vec2(-1.0,  1.0),\n"
    "      vec2( 1.0,  1.0)\n"
    "  );\n"
    "  vec2 position = positions[gl_VertexID];\n"
    "  v_uv = position * 0.5 + 0.5;\n"
    "  gl_Position = vec4(position, 0.0, 1.0);\n"
    "}\n";

static const char g_fragment_shader_source[] =
    "#version 330 core\n"
    "in vec2 v_uv;\n"
    "out vec4 frag_color;\n"
    "\n"
    "const int MAX_RELICS = 3;\n"
    "\n"
    "uniform sampler2D u_field_texture;\n"
    "uniform vec2 u_field_texel_size;\n"
    "uniform vec2 u_resolution;\n"
    "uniform float u_time;\n"
    "uniform int u_relic_count;\n"
    "uniform int u_dominant_index;\n"
    "uniform float u_symmetry[MAX_RELICS];\n"
    "uniform float u_ring_count[MAX_RELICS];\n"
    "uniform float u_glyph_density[MAX_RELICS];\n"
    "uniform float u_fracture_amount[MAX_RELICS];\n"
    "uniform float u_emissive_hue_bias[MAX_RELICS];\n"
    "uniform float u_pulse_speed[MAX_RELICS];\n"
    "uniform float u_pulse_intensity[MAX_RELICS];\n"
    "uniform float u_center_x[MAX_RELICS];\n"
    "uniform float u_center_y[MAX_RELICS];\n"
    "uniform float u_region_scale_x[MAX_RELICS];\n"
    "uniform float u_region_scale_y[MAX_RELICS];\n"
    "uniform float u_region_rotation[MAX_RELICS];\n"
    "uniform float u_layer_depth[MAX_RELICS];\n"
    "uniform float u_composition_weight[MAX_RELICS];\n"
    "uniform float u_overlap_softness[MAX_RELICS];\n"
    "uniform float u_pulse_phase[MAX_RELICS];\n"
    "uniform vec3 u_camera_position;\n"
    "uniform float u_camera_yaw;\n"
    "uniform float u_camera_pitch;\n"
    "uniform float u_camera_fov;\n"
    "\n"
    "float hash(vec2 p) {\n"
    "  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);\n"
    "}\n"
    "\n"
    "float noise(vec2 p) {\n"
    "  vec2 cell = floor(p);\n"
    "  vec2 cell_uv = fract(p);\n"
    "  vec2 weight = cell_uv * cell_uv * (3.0 - 2.0 * cell_uv);\n"
    "\n"
    "  float a = hash(cell);\n"
    "  float b = hash(cell + vec2(1.0, 0.0));\n"
    "  float c = hash(cell + vec2(0.0, 1.0));\n"
    "  float d = hash(cell + vec2(1.0, 1.0));\n"
    "\n"
    "  return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);\n"
    "}\n"
    "\n"
    "vec3 hue_palette(float hue) {\n"
    "  vec3 cool = vec3(0.08, 0.24, 0.28);\n"
    "  vec3 warm = vec3(0.38, 0.24, 0.10);\n"
    "  return mix(cool, warm, clamp(hue * 0.5 + 0.5, 0.0, 1.0));\n"
    "}\n"
    "\n"
    "mat3 rotation_x(float angle) {\n"
    "  float s = sin(angle);\n"
    "  float c = cos(angle);\n"
    "  return mat3(\n"
    "    1.0, 0.0, 0.0,\n"
    "    0.0, c, -s,\n"
    "    0.0, s, c\n"
    "  );\n"
    "}\n"
    "\n"
    "mat3 rotation_y(float angle) {\n"
    "  float s = sin(angle);\n"
    "  float c = cos(angle);\n"
    "  return mat3(\n"
    "    c, 0.0, s,\n"
    "    0.0, 1.0, 0.0,\n"
    "    -s, 0.0, c\n"
    "  );\n"
    "}\n"
    "\n"
    "mat2 rotation2d(float angle) {\n"
    "  float s = sin(angle);\n"
    "  float c = cos(angle);\n"
    "  return mat2(c, -s, s, c);\n"
    "}\n"
    "\n"
    "vec2 project_scene_uv(vec2 uv, float aspect, out float plane_fade) {\n"
    "  vec2 screen = uv * 2.0 - 1.0;\n"
    "  screen.x *= aspect;\n"
    "  float focal = 1.0 / tan(radians(max(u_camera_fov, 1.0)) * 0.5);\n"
    "  vec3 ray = normalize(vec3(screen, focal));\n"
    "  ray = rotation_y(u_camera_yaw) * rotation_x(u_camera_pitch) * ray;\n"
    "  if (ray.z <= 0.01) {\n"
    "    plane_fade = 0.0;\n"
    "    return vec2(-8.0);\n"
    "  }\n"
    "  float t = -u_camera_position.z / ray.z;\n"
    "  if (t <= 0.0) {\n"
    "    plane_fade = 0.0;\n"
    "    return vec2(-8.0);\n"
    "  }\n"
    "  plane_fade = smoothstep(0.03, 0.28, ray.z) * smoothstep(0.0, 0.35, t);\n"
    "  return u_camera_position.xy + ray.xy * t;\n"
    "}\n"
    "\n"
    "float region_metric(vec2 uv, vec2 center, vec2 scale, float rotation, float aspect, out vec2 aligned) {\n"
    "  vec2 local = uv - center;\n"
    "  local.x *= aspect;\n"
    "  vec2 corrected_scale = vec2(max(scale.x * aspect, 0.001), max(scale.y, 0.001));\n"
    "  aligned = rotation2d(rotation) * local;\n"
    "  vec2 normalized = aligned / corrected_scale;\n"
    "  return dot(normalized, normalized);\n"
    "}\n"
    "\n"
    "float ridge_band(float value, float center, float width) {\n"
    "  return exp(-abs(value - center) * width);\n"
    "}\n"
    "\n"
    "void main(void) {\n"
    "  vec2 uv = v_uv;\n"
    "  float aspect = u_resolution.x / max(u_resolution.y, 1.0);\n"
    "  float plane_fade = 0.0;\n"
    "  vec2 scene_uv = project_scene_uv(uv, aspect, plane_fade);\n"
    "  vec2 sample_uv = clamp(scene_uv, vec2(0.001), vec2(0.999));\n"
    "  float screen_radial = length(uv * 2.0 - 1.0);\n"
    "  vec2 field_grad = vec2(\n"
    "    texture(u_field_texture, clamp(sample_uv + vec2(u_field_texel_size.x, 0.0), 0.001, 0.999)).r -\n"
    "    texture(u_field_texture, clamp(sample_uv - vec2(u_field_texel_size.x, 0.0), 0.001, 0.999)).r,\n"
    "    texture(u_field_texture, clamp(sample_uv + vec2(0.0, u_field_texel_size.y), 0.001, 0.999)).r -\n"
    "    texture(u_field_texture, clamp(sample_uv - vec2(0.0, u_field_texel_size.y), 0.001, 0.999)).r\n"
    "  );\n"
    "  float field_energy = texture(u_field_texture, clamp(sample_uv + field_grad * 0.10, 0.001, 0.999)).r;\n"
    "  float field_ridge = smoothstep(0.24, 0.80, field_energy);\n"
    "  float field_crack = smoothstep(0.38, 0.92, abs(sin(field_energy * 16.0 - u_time * 0.45)));\n"
    "  vec2 chamber = scene_uv - vec2(0.5, 0.54);\n"
    "  chamber.x *= aspect;\n"
    "  chamber += field_grad * 0.12;\n"
    "\n"
    "  float time = u_time * 0.14;\n"
    "  float radial = length(chamber);\n"
    "  float mist = noise(chamber * 4.2 + vec2(time, -time * 0.55));\n"
    "  float dust = noise(chamber * 8.0 - vec2(time * 1.3, time * 0.7));\n"
    "  float vault = 1.0 - smoothstep(0.10, 1.05, radial + mist * 0.08);\n"
    "  float chamber_wave = 0.5 + 0.5 * sin(chamber.y * 11.0 - time * 5.0 + mist * 1.6);\n"
    "  float view_window = plane_fade * (1.0 - smoothstep(0.95, 1.85, radial));\n"
    "\n"
    "  vec3 base = vec3(0.018, 0.026, 0.040);\n"
    "  vec3 low_glow = vec3(0.07, 0.12, 0.15);\n"
    "  vec3 warm_haze = vec3(0.24, 0.19, 0.09);\n"
    "  vec3 color = base;\n"
    "  color += low_glow * (0.12 + 0.16 * screen_radial + 0.08 * plane_fade);\n"
    "  color += warm_haze * dust * (0.02 + 0.08 * plane_fade);\n"
    "  color += vec3(0.08, 0.11, 0.12) * mist * 0.03;\n"
    "  color -= vec3(0.04, 0.04, 0.03) * field_crack * plane_fade * (0.20 + 0.30 * field_energy);\n"
    "\n"
    "  float presence_sum = 0.0;\n"
    "  float overlap_sum = 0.0;\n"
    "  float dominant_presence = 0.0;\n"
    "  vec3 shared_atmosphere = vec3(0.0);\n"
    "\n"
    "  for (int i = 0; i < MAX_RELICS; ++i) {\n"
    "    if (i >= u_relic_count) {\n"
    "      break;\n"
    "    }\n"
    "\n"
    "    vec2 aligned;\n"
    "    float metric = region_metric(\n"
    "      uv,\n"
    "      vec2(u_center_x[i], u_center_y[i]),\n"
    "      vec2(u_region_scale_x[i], u_region_scale_y[i]),\n"
    "      u_region_rotation[i],\n"
    "      aspect,\n"
    "      aligned\n"
    "    );\n"
    "    float mask = exp(-metric * (1.05 + 0.85 * u_layer_depth[i]));\n"
    "    float halo = exp(-metric * (0.72 + 0.45 * u_overlap_softness[i]));\n"
    "    float presence = mask * (0.55 + 0.45 * u_composition_weight[i]);\n"
    "    vec3 tint = hue_palette(u_emissive_hue_bias[i]);\n"
    "\n"
    "    presence_sum += presence;\n"
    "    overlap_sum += presence * (0.55 + 0.45 * u_overlap_softness[i]);\n"
    "    shared_atmosphere += tint * halo * (0.05 + 0.06 * u_glyph_density[i]) * (1.0 - 0.35 * u_layer_depth[i]) *\n"
    "      (0.65 + 0.35 * u_pulse_intensity[i]);\n"
    "    if (i == u_dominant_index) {\n"
    "      dominant_presence = presence;\n"
    "    }\n"
    "  }\n"
    "\n"
    "  float overlap = smoothstep(0.72, 1.50, overlap_sum);\n"
    "  color += shared_atmosphere * plane_fade * (0.70 + 0.35 * field_ridge + 0.20 * overlap);\n"
    "  color += vec3(0.06, 0.08, 0.10) * chamber_wave * vault * plane_fade * 0.05;\n"
    "\n"
    "  vec3 layered_glow = vec3(0.0);\n"
    "  vec3 relic_detail = vec3(0.0);\n"
    "  float silhouette_occlusion = 0.0;\n"
    "\n"
    "  for (int i = 0; i < MAX_RELICS; ++i) {\n"
    "    if (i >= u_relic_count) {\n"
    "      break;\n"
    "    }\n"
    "\n"
    "    float role = i == u_dominant_index ? 1.0 : 0.0;\n"
    "    vec2 aligned;\n"
    "    float metric = region_metric(\n"
    "      uv + field_grad * (0.02 + 0.04 * (1.0 - u_layer_depth[i])),\n"
    "      vec2(u_center_x[i], u_center_y[i]),\n"
    "      vec2(u_region_scale_x[i], u_region_scale_y[i]),\n"
    "      u_region_rotation[i],\n"
    "      aspect,\n"
    "      aligned\n"
    "    );\n"
    "    float local_radial = sqrt(max(metric, 0.0));\n"
    "    float local_angle = atan(aligned.y, aligned.x);\n"
    "    float mask = exp(-metric * (1.05 + 0.85 * u_layer_depth[i]));\n"
    "    float interior = 1.0 - smoothstep(0.22, 1.12, metric);\n"
    "    float shell = ridge_band(metric, 0.78 - 0.10 * role + 0.06 * u_ring_count[i], 8.0 + 10.0 * u_composition_weight[i]);\n"
    "    float inner_band = ridge_band(metric, 0.36 + 0.12 * u_ring_count[i], 12.0 + 8.0 * u_glyph_density[i]);\n"
    "    float symmetry = 3.0 + 7.0 * u_symmetry[i];\n"
    "    float local_time = u_time * (0.24 + 0.65 * u_pulse_speed[i]) + u_pulse_phase[i];\n"
    "    float pulse = (0.5 + 0.5 * sin(local_time + local_radial * (9.0 + 10.0 * u_ring_count[i]) - metric * (1.0 + 2.2 * u_fracture_amount[i]))) *\n"
    "      (0.45 + 0.55 * u_pulse_intensity[i]);\n"
    "    float ribs = 0.5 + 0.5 * cos(local_angle * symmetry + local_time * (0.40 + 0.30 * role));\n"
    "    float runes = 0.5 + 0.5 * sin(local_radial * (12.0 + 16.0 * u_ring_count[i]) - local_time * (1.6 + 0.6 * u_fracture_amount[i]));\n"
    "    float fracture_noise = noise(aligned * (6.0 + 8.0 * u_fracture_amount[i]) + vec2(local_time * 0.35, -local_time * 0.22));\n"
    "    float glyphs = smoothstep(0.64 - 0.16 * u_fracture_amount[i], 0.94, ribs * runes);\n"
    "    float fracture_mask = mix(1.0, fracture_noise, 0.75 * u_fracture_amount[i]);\n"
    "    float presence = mask * (0.55 + 0.45 * u_composition_weight[i]);\n"
    "    float crowding = max(0.0, presence_sum - presence);\n"
    "    float overlap_relief = 1.0 / (1.0 + crowding * mix(1.25, 0.80, role));\n"
    "    vec3 tint = hue_palette(u_emissive_hue_bias[i]);\n"
    "    vec3 stone = mix(vec3(0.10, 0.12, 0.14), vec3(0.16, 0.13, 0.10), clamp(u_emissive_hue_bias[i] * 0.5 + 0.5, 0.0, 1.0));\n"
    "    float carved_void = interior * (0.10 + 0.14 * role) * (1.0 - 0.30 * field_ridge);\n"
    "    float halo = exp(-metric * (1.30 + 1.20 * u_layer_depth[i])) * (0.45 + 0.55 * pulse);\n"
    "    float focus_core = exp(-metric * (3.2 - 0.7 * role)) * (0.25 + 0.75 * pulse);\n"
    "    float support_glow = inner_band * fracture_mask * (0.18 + 0.20 * pulse);\n"
    "\n"
    "    silhouette_occlusion += carved_void + shell * (0.05 + 0.06 * (1.0 - role));\n"
    "    layered_glow += tint * halo * overlap_relief * (0.14 + 0.12 * role + 0.08 * field_ridge);\n"
    "    layered_glow += tint * support_glow * overlap_relief * (0.40 + 0.20 * u_overlap_softness[i]);\n"
    "    relic_detail += tint * glyphs * shell * fracture_mask * overlap_relief * (0.24 + 0.30 * role);\n"
    "    relic_detail += tint * inner_band * glyphs * overlap_relief * (0.10 + 0.18 * role);\n"
    "    relic_detail += mix(stone, tint, 0.55 + 0.25 * role) * focus_core * overlap_relief * (0.08 + 0.16 * role);\n"
    "  }\n"
    "\n"
    "  color -= vec3(0.11, 0.10, 0.09) * silhouette_occlusion * plane_fade;\n"
    "  color += layered_glow * plane_fade;\n"
    "  color += relic_detail * plane_fade;\n"
    "  color += vec3(0.10, 0.13, 0.16) * overlap * plane_fade * (0.05 + 0.10 * field_ridge);\n"
    "  color += vec3(0.14, 0.18, 0.20) * dominant_presence * plane_fade * 0.06;\n"
    "  color = mix(base * 0.70 + vec3(0.015, 0.020, 0.028) * (1.0 - screen_radial), color, view_window + 0.20 * plane_fade);\n"
    "  color *= 1.0 - 0.10 * smoothstep(0.10, 0.95, screen_radial);\n"
    "  color = max(color, vec3(0.0));\n"
    "  color = color / (1.0 + color);\n"
    "  color = pow(color, vec3(0.94));\n"
    "  frag_color = vec4(color, 1.0);\n"
    "}\n";

static const char g_post_fragment_shader_source[] =
    "#version 330 core\n"
    "in vec2 v_uv;\n"
    "out vec4 frag_color;\n"
    "\n"
    "uniform sampler2D u_scene_texture;\n"
    "uniform vec2 u_resolution;\n"
    "uniform float u_time;\n"
    "uniform int u_post_enabled;\n"
    "uniform float u_bloom_strength;\n"
    "uniform float u_vignette_strength;\n"
    "uniform float u_exposure;\n"
    "\n"
    "float luminance(vec3 color) {\n"
    "  return dot(color, vec3(0.2126, 0.7152, 0.0722));\n"
    "}\n"
    "\n"
    "vec3 sample_scene(vec2 uv) {\n"
    "  return texture(u_scene_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;\n"
    "}\n"
    "\n"
    "void main(void) {\n"
    "  vec2 uv = v_uv;\n"
    "  vec3 base = sample_scene(uv);\n"
    "\n"
    "  if (u_post_enabled == 0) {\n"
    "    frag_color = vec4(base, 1.0);\n"
    "    return;\n"
    "  }\n"
    "\n"
    "  vec2 texel = 1.0 / max(u_resolution, vec2(1.0));\n"
    "  vec3 bloom = vec3(0.0);\n"
    "  float bloom_weight = 0.0;\n"
    "\n"
    "  for (int y = -2; y <= 2; ++y) {\n"
    "    for (int x = -2; x <= 2; ++x) {\n"
    "      vec2 offset = vec2(float(x), float(y));\n"
    "      float kernel = 1.0 / (1.0 + dot(offset, offset));\n"
    "      vec3 sample_color = sample_scene(uv + offset * texel * 2.0);\n"
    "      float bright = max(luminance(sample_color) - 0.36, 0.0);\n"
    "      bloom += sample_color * bright * kernel;\n"
    "      bloom_weight += kernel;\n"
    "    }\n"
    "  }\n"
    "\n"
    "  bloom /= max(bloom_weight, 0.0001);\n"
    "\n"
    "  vec3 color = base + bloom * u_bloom_strength * 2.4;\n"
    "  color *= u_exposure;\n"
    "  color = color / (1.0 + 0.28 * color);\n"
    "\n"
    "  vec2 centered = uv - 0.5;\n"
    "  centered.x *= u_resolution.x / max(u_resolution.y, 1.0);\n"
    "  float vignette = 1.0 - smoothstep(0.35, 1.08, length(centered));\n"
    "  vignette = mix(1.0, vignette, clamp(u_vignette_strength, 0.0, 1.0));\n"
    "  color *= vignette;\n"
    "  color += bloom * 0.05 * (0.5 + 0.5 * sin(u_time * 0.25));\n"
    "  color = pow(max(color, vec3(0.0)), vec3(0.96));\n"
    "\n"
    "  frag_color = vec4(color, 1.0);\n"
    "}\n";

#define LOAD_GL_PROC(type, target, symbol)                                      \
  do {                                                                          \
    target = (type)glfwGetProcAddress(symbol);                                  \
    if (target == NULL) {                                                       \
      fprintf(stderr, "[FAIL] Failed to load OpenGL function %s.\n", symbol);   \
      return 0;                                                                 \
    }                                                                           \
  } while (0)

static void destroy_renderer(void) {
  if (glDeleteFramebuffersPtr != NULL && g_scene_framebuffer != 0) {
    glDeleteFramebuffersPtr(1, &g_scene_framebuffer);
    g_scene_framebuffer = 0;
  }

  if (g_scene_color_texture != 0) {
    glDeleteTextures(1, &g_scene_color_texture);
    g_scene_color_texture = 0;
  }

  if (g_field_texture != 0) {
    glDeleteTextures(1, &g_field_texture);
    g_field_texture = 0;
  }

  if (glDeleteVertexArraysPtr != NULL && g_vertex_array != 0) {
    glDeleteVertexArraysPtr(1, &g_vertex_array);
    g_vertex_array = 0;
  }

  if (glDeleteProgramPtr != NULL && g_program != 0) {
    glDeleteProgramPtr(g_program);
    g_program = 0;
  }

  if (glDeleteProgramPtr != NULL && g_post_program != 0) {
    glDeleteProgramPtr(g_post_program);
    g_post_program = 0;
  }

  g_u_field_texture = -1;
  g_u_field_texel_size = -1;
  g_u_resolution = -1;
  g_u_time = -1;
  g_u_relic_count = -1;
  g_u_dominant_index = -1;
  g_u_symmetry = -1;
  g_u_ring_count = -1;
  g_u_glyph_density = -1;
  g_u_fracture_amount = -1;
  g_u_emissive_hue_bias = -1;
  g_u_pulse_speed = -1;
  g_u_pulse_intensity = -1;
  g_u_center_x = -1;
  g_u_center_y = -1;
  g_u_region_scale_x = -1;
  g_u_region_scale_y = -1;
  g_u_region_rotation = -1;
  g_u_layer_depth = -1;
  g_u_composition_weight = -1;
  g_u_overlap_softness = -1;
  g_u_pulse_phase = -1;
  g_u_camera_position = -1;
  g_u_camera_yaw = -1;
  g_u_camera_pitch = -1;
  g_u_camera_fov = -1;
  g_u_post_scene_texture = -1;
  g_u_post_resolution = -1;
  g_u_post_time = -1;
  g_u_post_enabled = -1;
  g_u_post_bloom_strength = -1;
  g_u_post_vignette_strength = -1;
  g_u_post_exposure = -1;
  g_dominant_index = 0;
  g_field_width = 0;
  g_field_height = 0;
  g_scene_width = 0;
  g_scene_height = 0;
  g_scroll_delta = 0.0f;
  g_cursor_initialized = 0;
  g_capture_requested = 0;
}

static int load_gl_functions(void) {
  LOAD_GL_PROC(PFNGLACTIVETEXTUREPROC, glActiveTexturePtr, "glActiveTexture");
  LOAD_GL_PROC(PFNGLATTACHSHADERPROC, glAttachShaderPtr, "glAttachShader");
  LOAD_GL_PROC(PFNGLBINDFRAMEBUFFERPROC, glBindFramebufferPtr, "glBindFramebuffer");
  LOAD_GL_PROC(PFNGLBINDVERTEXARRAYPROC, glBindVertexArrayPtr, "glBindVertexArray");
  LOAD_GL_PROC(PFNGLCHECKFRAMEBUFFERSTATUSPROC, glCheckFramebufferStatusPtr, "glCheckFramebufferStatus");
  LOAD_GL_PROC(PFNGLCOMPILESHADERPROC, glCompileShaderPtr, "glCompileShader");
  LOAD_GL_PROC(PFNGLCREATEPROGRAMPROC, glCreateProgramPtr, "glCreateProgram");
  LOAD_GL_PROC(PFNGLCREATESHADERPROC, glCreateShaderPtr, "glCreateShader");
  LOAD_GL_PROC(PFNGLDELETEFRAMEBUFFERSPROC, glDeleteFramebuffersPtr, "glDeleteFramebuffers");
  LOAD_GL_PROC(PFNGLDELETEPROGRAMPROC, glDeleteProgramPtr, "glDeleteProgram");
  LOAD_GL_PROC(PFNGLDELETESHADERPROC, glDeleteShaderPtr, "glDeleteShader");
  LOAD_GL_PROC(PFNGLDELETEVERTEXARRAYSPROC, glDeleteVertexArraysPtr, "glDeleteVertexArrays");
  LOAD_GL_PROC(PFNGLFRAMEBUFFERTEXTURE2DPROC, glFramebufferTexture2DPtr, "glFramebufferTexture2D");
  LOAD_GL_PROC(PFNGLGENFRAMEBUFFERSPROC, glGenFramebuffersPtr, "glGenFramebuffers");
  LOAD_GL_PROC(PFNGLGENVERTEXARRAYSPROC, glGenVertexArraysPtr, "glGenVertexArrays");
  LOAD_GL_PROC(PFNGLGETPROGRAMINFOLOGPROC, glGetProgramInfoLogPtr, "glGetProgramInfoLog");
  LOAD_GL_PROC(PFNGLGETPROGRAMIVPROC, glGetProgramivPtr, "glGetProgramiv");
  LOAD_GL_PROC(PFNGLGETSHADERINFOLOGPROC, glGetShaderInfoLogPtr, "glGetShaderInfoLog");
  LOAD_GL_PROC(PFNGLGETSHADERIVPROC, glGetShaderivPtr, "glGetShaderiv");
  LOAD_GL_PROC(PFNGLGETUNIFORMLOCATIONPROC, glGetUniformLocationPtr, "glGetUniformLocation");
  LOAD_GL_PROC(PFNGLLINKPROGRAMPROC, glLinkProgramPtr, "glLinkProgram");
  LOAD_GL_PROC(PFNGLSHADERSOURCEPROC, glShaderSourcePtr, "glShaderSource");
  LOAD_GL_PROC(PFNGLUNIFORM1FVPROC, glUniform1fvPtr, "glUniform1fv");
  LOAD_GL_PROC(PFNGLUNIFORM1IPROC, glUniform1iPtr, "glUniform1i");
  LOAD_GL_PROC(PFNGLUNIFORM1FPROC, glUniform1fPtr, "glUniform1f");
  LOAD_GL_PROC(PFNGLUNIFORM2FPROC, glUniform2fPtr, "glUniform2f");
  LOAD_GL_PROC(PFNGLUNIFORM3FPROC, glUniform3fPtr, "glUniform3f");
  LOAD_GL_PROC(PFNGLUSEPROGRAMPROC, glUseProgramPtr, "glUseProgram");

  return 1;
}

static void print_shader_log(GLuint shader, const char *label) {
  GLint log_length = 0;
  char *log_buffer = NULL;

  glGetShaderivPtr(shader, GL_INFO_LOG_LENGTH, &log_length);
  if (log_length <= 1) {
    fprintf(stderr, "[FAIL] %s shader compilation failed with no log output.\n", label);
    return;
  }

  log_buffer = (char *)malloc((size_t)log_length);
  if (log_buffer == NULL) {
    fprintf(stderr, "[FAIL] %s shader compilation failed and log allocation failed.\n", label);
    return;
  }

  glGetShaderInfoLogPtr(shader, log_length, NULL, log_buffer);
  fprintf(stderr, "[FAIL] %s shader compilation failed:\n%s\n", label, log_buffer);
  free(log_buffer);
}

static void print_program_log(GLuint program) {
  GLint log_length = 0;
  char *log_buffer = NULL;

  glGetProgramivPtr(program, GL_INFO_LOG_LENGTH, &log_length);
  if (log_length <= 1) {
    fprintf(stderr, "[FAIL] Shader program link failed with no log output.\n");
    return;
  }

  log_buffer = (char *)malloc((size_t)log_length);
  if (log_buffer == NULL) {
    fprintf(stderr, "[FAIL] Shader program link failed and log allocation failed.\n");
    return;
  }

  glGetProgramInfoLogPtr(program, log_length, NULL, log_buffer);
  fprintf(stderr, "[FAIL] Shader program link failed:\n%s\n", log_buffer);
  free(log_buffer);
}

static GLuint compile_shader(GLenum shader_type, const char *label, const char *source) {
  GLint compile_status = GL_FALSE;
  GLuint shader = glCreateShaderPtr(shader_type);

  if (shader == 0) {
    fprintf(stderr, "[FAIL] Failed to create %s shader object.\n", label);
    return 0;
  }

  glShaderSourcePtr(shader, 1, &source, NULL);
  glCompileShaderPtr(shader);
  glGetShaderivPtr(shader, GL_COMPILE_STATUS, &compile_status);

  if (compile_status != GL_TRUE) {
    print_shader_log(shader, label);
    glDeleteShaderPtr(shader);
    return 0;
  }

  return shader;
}

static int create_shader_pipeline(void) {
  GLint link_status = GL_FALSE;
  GLuint vertex_shader = 0;
  GLuint fragment_shader = 0;

  vertex_shader =
      compile_shader(GL_VERTEX_SHADER, "vertex", g_vertex_shader_source);
  if (vertex_shader == 0) {
    return 0;
  }

  fragment_shader =
      compile_shader(GL_FRAGMENT_SHADER, "fragment", g_fragment_shader_source);
  if (fragment_shader == 0) {
    glDeleteShaderPtr(vertex_shader);
    return 0;
  }

  g_program = glCreateProgramPtr();
  if (g_program == 0) {
    fprintf(stderr, "[FAIL] Failed to create shader program object.\n");
    glDeleteShaderPtr(vertex_shader);
    glDeleteShaderPtr(fragment_shader);
    return 0;
  }

  glAttachShaderPtr(g_program, vertex_shader);
  glAttachShaderPtr(g_program, fragment_shader);
  glLinkProgramPtr(g_program);
  glGetProgramivPtr(g_program, GL_LINK_STATUS, &link_status);

  glDeleteShaderPtr(vertex_shader);
  glDeleteShaderPtr(fragment_shader);

  if (link_status != GL_TRUE) {
    print_program_log(g_program);
    destroy_renderer();
    return 0;
  }

  g_u_field_texture = glGetUniformLocationPtr(g_program, "u_field_texture");
  g_u_field_texel_size = glGetUniformLocationPtr(g_program, "u_field_texel_size");
  g_u_resolution = glGetUniformLocationPtr(g_program, "u_resolution");
  g_u_time = glGetUniformLocationPtr(g_program, "u_time");
  g_u_relic_count = glGetUniformLocationPtr(g_program, "u_relic_count");
  g_u_dominant_index = glGetUniformLocationPtr(g_program, "u_dominant_index");
  g_u_symmetry = glGetUniformLocationPtr(g_program, "u_symmetry");
  g_u_ring_count = glGetUniformLocationPtr(g_program, "u_ring_count");
  g_u_glyph_density = glGetUniformLocationPtr(g_program, "u_glyph_density");
  g_u_fracture_amount = glGetUniformLocationPtr(g_program, "u_fracture_amount");
  g_u_emissive_hue_bias = glGetUniformLocationPtr(g_program, "u_emissive_hue_bias");
  g_u_pulse_speed = glGetUniformLocationPtr(g_program, "u_pulse_speed");
  g_u_pulse_intensity = glGetUniformLocationPtr(g_program, "u_pulse_intensity");
  g_u_center_x = glGetUniformLocationPtr(g_program, "u_center_x");
  g_u_center_y = glGetUniformLocationPtr(g_program, "u_center_y");
  g_u_region_scale_x = glGetUniformLocationPtr(g_program, "u_region_scale_x");
  g_u_region_scale_y = glGetUniformLocationPtr(g_program, "u_region_scale_y");
  g_u_region_rotation = glGetUniformLocationPtr(g_program, "u_region_rotation");
  g_u_layer_depth = glGetUniformLocationPtr(g_program, "u_layer_depth");
  g_u_composition_weight = glGetUniformLocationPtr(g_program, "u_composition_weight");
  g_u_overlap_softness = glGetUniformLocationPtr(g_program, "u_overlap_softness");
  g_u_pulse_phase = glGetUniformLocationPtr(g_program, "u_pulse_phase");
  g_u_camera_position = glGetUniformLocationPtr(g_program, "u_camera_position");
  g_u_camera_yaw = glGetUniformLocationPtr(g_program, "u_camera_yaw");
  g_u_camera_pitch = glGetUniformLocationPtr(g_program, "u_camera_pitch");
  g_u_camera_fov = glGetUniformLocationPtr(g_program, "u_camera_fov");

  if (g_u_field_texture < 0 || g_u_field_texel_size < 0 ||
      g_u_resolution < 0 || g_u_time < 0 || g_u_relic_count < 0 ||
      g_u_dominant_index < 0 ||
      g_u_symmetry < 0 || g_u_ring_count < 0 || g_u_glyph_density < 0 ||
      g_u_fracture_amount < 0 || g_u_emissive_hue_bias < 0 || g_u_pulse_speed < 0 ||
      g_u_pulse_intensity < 0 ||
      g_u_center_x < 0 || g_u_center_y < 0 ||
      g_u_region_scale_x < 0 || g_u_region_scale_y < 0 || g_u_region_rotation < 0 ||
      g_u_layer_depth < 0 || g_u_composition_weight < 0 ||
      g_u_overlap_softness < 0 || g_u_pulse_phase < 0 ||
      g_u_camera_position < 0 || g_u_camera_yaw < 0 ||
      g_u_camera_pitch < 0 || g_u_camera_fov < 0) {
    fprintf(stderr, "[FAIL] Failed to locate required shader uniforms.\n");
    destroy_renderer();
    return 0;
  }

  glGenVertexArraysPtr(1, &g_vertex_array);
  if (g_vertex_array == 0) {
    fprintf(stderr, "[FAIL] Failed to create fullscreen quad vertex array.\n");
    destroy_renderer();
    return 0;
  }

  glGenTextures(1, &g_field_texture);
  if (g_field_texture == 0) {
    fprintf(stderr, "[FAIL] Failed to create resonance field texture.\n");
    destroy_renderer();
    return 0;
  }

  glBindTexture(GL_TEXTURE_2D, g_field_texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, 1, 1, 0, GL_RED, GL_FLOAT, NULL);
  glBindTexture(GL_TEXTURE_2D, 0);

  return 1;
}

static int create_post_pipeline(void) {
  GLint link_status = GL_FALSE;
  GLuint vertex_shader = 0;
  GLuint fragment_shader = 0;

  vertex_shader =
      compile_shader(GL_VERTEX_SHADER, "post vertex", g_vertex_shader_source);
  if (vertex_shader == 0) {
    return 0;
  }

  fragment_shader =
      compile_shader(GL_FRAGMENT_SHADER, "post fragment", g_post_fragment_shader_source);
  if (fragment_shader == 0) {
    glDeleteShaderPtr(vertex_shader);
    return 0;
  }

  g_post_program = glCreateProgramPtr();
  if (g_post_program == 0) {
    fprintf(stderr, "[FAIL] Failed to create post-processing shader program object.\n");
    glDeleteShaderPtr(vertex_shader);
    glDeleteShaderPtr(fragment_shader);
    return 0;
  }

  glAttachShaderPtr(g_post_program, vertex_shader);
  glAttachShaderPtr(g_post_program, fragment_shader);
  glLinkProgramPtr(g_post_program);
  glGetProgramivPtr(g_post_program, GL_LINK_STATUS, &link_status);

  glDeleteShaderPtr(vertex_shader);
  glDeleteShaderPtr(fragment_shader);

  if (link_status != GL_TRUE) {
    print_program_log(g_post_program);
    destroy_renderer();
    return 0;
  }

  g_u_post_scene_texture = glGetUniformLocationPtr(g_post_program, "u_scene_texture");
  g_u_post_resolution = glGetUniformLocationPtr(g_post_program, "u_resolution");
  g_u_post_time = glGetUniformLocationPtr(g_post_program, "u_time");
  g_u_post_enabled = glGetUniformLocationPtr(g_post_program, "u_post_enabled");
  g_u_post_bloom_strength = glGetUniformLocationPtr(g_post_program, "u_bloom_strength");
  g_u_post_vignette_strength = glGetUniformLocationPtr(g_post_program, "u_vignette_strength");
  g_u_post_exposure = glGetUniformLocationPtr(g_post_program, "u_exposure");

  if (g_u_post_scene_texture < 0 || g_u_post_resolution < 0 || g_u_post_time < 0 ||
      g_u_post_enabled < 0 || g_u_post_bloom_strength < 0 ||
      g_u_post_vignette_strength < 0 || g_u_post_exposure < 0) {
    fprintf(stderr, "[FAIL] Failed to locate required post-processing uniforms.\n");
    destroy_renderer();
    return 0;
  }

  return 1;
}

static int ensure_scene_framebuffer(int width, int height) {
  GLenum framebuffer_status = GL_FRAMEBUFFER_COMPLETE;

  if (width <= 0 || height <= 0) {
    return 0;
  }

  if (g_scene_framebuffer == 0) {
    glGenFramebuffersPtr(1, &g_scene_framebuffer);
  }

  if (g_scene_color_texture == 0) {
    glGenTextures(1, &g_scene_color_texture);
  }

  if (g_scene_framebuffer == 0 || g_scene_color_texture == 0) {
    fprintf(stderr, "[FAIL] Failed to create off-screen framebuffer resources.\n");
    return 0;
  }

  if (g_scene_width == width && g_scene_height == height) {
    return 1;
  }

  glBindTexture(GL_TEXTURE_2D, g_scene_color_texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(
      GL_TEXTURE_2D,
      0,
      GL_RGBA16F,
      width,
      height,
      0,
      GL_RGBA,
      GL_FLOAT,
      NULL);

  glBindFramebufferPtr(GL_FRAMEBUFFER, g_scene_framebuffer);
  glFramebufferTexture2DPtr(
      GL_FRAMEBUFFER,
      GL_COLOR_ATTACHMENT0,
      GL_TEXTURE_2D,
      g_scene_color_texture,
      0);
  framebuffer_status = glCheckFramebufferStatusPtr(GL_FRAMEBUFFER);
  glBindFramebufferPtr(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);

  if (framebuffer_status != GL_FRAMEBUFFER_COMPLETE) {
    fprintf(stderr, "[FAIL] Off-screen framebuffer is incomplete.\n");
    return 0;
  }

  g_scene_width = width;
  g_scene_height = height;
  return 1;
}

static int ensure_directory_exists(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }

  if (mkdir(path, 0777) == 0 || errno == EEXIST) {
    return 1;
  }

  fprintf(stderr, "[FAIL] Failed to create capture directory %s: %s\n", path, strerror(errno));
  return 0;
}

static int find_capture_path(char *path_buffer, size_t buffer_size) {
  int capture_index = 1;
  FILE *existing_file = NULL;

  if (path_buffer == NULL || buffer_size == 0) {
    return 0;
  }

  while (capture_index < 100000) {
    snprintf(
        path_buffer,
        buffer_size,
        "%s/hrf_capture_%04d.ppm",
        g_capture_directory,
        capture_index);
    existing_file = fopen(path_buffer, "rb");
    if (existing_file == NULL) {
      return 1;
    }
    fclose(existing_file);
    capture_index += 1;
  }

  fprintf(stderr, "[FAIL] Could not allocate a new capture filename in %s.\n", g_capture_directory);
  return 0;
}

static void capture_framebuffer_if_requested(int width, int height) {
  char capture_path[HRF_CAPTURE_PATH_MAX];
  FILE *output_file = NULL;
  unsigned char *pixels = NULL;
  size_t row_stride = 0;
  int row = 0;

  if (!g_capture_requested) {
    return;
  }

  g_capture_requested = 0;

  if (!ensure_directory_exists(g_capture_directory)) {
    return;
  }

  if (!find_capture_path(capture_path, sizeof(capture_path))) {
    return;
  }

  row_stride = (size_t)width * 3u;
  pixels = (unsigned char *)malloc(row_stride * (size_t)height);
  if (pixels == NULL) {
    fprintf(stderr, "[FAIL] Failed to allocate screenshot buffer.\n");
    return;
  }

  glPixelStorei(GL_PACK_ALIGNMENT, 1);
  glReadBuffer(GL_BACK);
  glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels);

  output_file = fopen(capture_path, "wb");
  if (output_file == NULL) {
    fprintf(stderr, "[FAIL] Failed to open capture file %s.\n", capture_path);
    free(pixels);
    return;
  }

  fprintf(output_file, "P6\n%d %d\n255\n", width, height);
  for (row = height - 1; row >= 0; --row) {
    fwrite(pixels + (size_t)row * row_stride, 1, row_stride, output_file);
  }

  fclose(output_file);
  free(pixels);
  printf("[capture] saved %s\n", capture_path);
  fflush(stdout);
}

int hrf_gl_init(int width, int height, const char *title) {
  const char *error_message = NULL;

  if (!glfwInit()) {
    glfwGetError(&error_message);
    print_glfw_backend_hint(error_message);
    return 0;
  }

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);

  g_window = glfwCreateWindow(width, height, title, NULL, NULL);
  if (g_window == NULL) {
    glfwGetError(&error_message);
    fprintf(
        stderr,
        "[FAIL] glfwCreateWindow failed%s%s\n",
        error_message != NULL ? ": " : ".",
        error_message != NULL ? error_message : "");
    glfwTerminate();
    return 0;
  }

  glfwMakeContextCurrent(g_window);
  glfwSwapInterval(1);
  glfwSetScrollCallback(g_window, on_scroll);

  if (!load_gl_functions()) {
    hrf_gl_shutdown();
    return 0;
  }

  if (!create_shader_pipeline()) {
    hrf_gl_shutdown();
    return 0;
  }

  if (!create_post_pipeline()) {
    hrf_gl_shutdown();
    return 0;
  }

  return 1;
}

int hrf_gl_should_close(void) {
  if (g_window == NULL) {
    return 1;
  }

  return glfwWindowShouldClose(g_window);
}

double hrf_gl_get_time(void) {
  return glfwGetTime();
}

static int key_is_down(int key) {
  if (g_window == NULL || key < 0 || key > GLFW_KEY_LAST) {
    return 0;
  }

  return glfwGetKey(g_window, key) == GLFW_PRESS;
}

static int consume_key_press(int key) {
  int current_state = 0;
  int pressed = 0;

  if (key < 0 || key > GLFW_KEY_LAST) {
    return 0;
  }

  current_state = key_is_down(key);
  pressed = current_state && !g_prev_key_states[key];
  g_prev_key_states[key] = current_state;
  return pressed;
}

void hrf_gl_get_input_state(hrf_input_state *input_state) {
  double cursor_x = 0.0;
  double cursor_y = 0.0;
  double delta_x = 0.0;
  double delta_y = 0.0;

  if (input_state == NULL) {
    return;
  }

  memset(input_state, 0, sizeof(*input_state));

  if (g_window == NULL) {
    return;
  }

  input_state->move_x = (key_is_down(GLFW_KEY_D) ? 1.0f : 0.0f) -
                        (key_is_down(GLFW_KEY_A) ? 1.0f : 0.0f);
  input_state->move_y = (key_is_down(GLFW_KEY_E) ? 1.0f : 0.0f) -
                        (key_is_down(GLFW_KEY_Q) ? 1.0f : 0.0f);
  input_state->move_z = (key_is_down(GLFW_KEY_W) ? 1.0f : 0.0f) -
                        (key_is_down(GLFW_KEY_S) ? 1.0f : 0.0f);
  input_state->orbit_x = (key_is_down(GLFW_KEY_RIGHT) ? 1.0f : 0.0f) -
                         (key_is_down(GLFW_KEY_LEFT) ? 1.0f : 0.0f);
  input_state->orbit_y = (key_is_down(GLFW_KEY_UP) ? 1.0f : 0.0f) -
                         (key_is_down(GLFW_KEY_DOWN) ? 1.0f : 0.0f);
  input_state->zoom_axis = (key_is_down(GLFW_KEY_Z) ? 1.0f : 0.0f) -
                           (key_is_down(GLFW_KEY_X) ? 1.0f : 0.0f);
  input_state->scroll_delta = g_scroll_delta;
  g_scroll_delta = 0.0f;

  glfwGetCursorPos(g_window, &cursor_x, &cursor_y);
  if (!g_cursor_initialized) {
    g_prev_cursor_x = cursor_x;
    g_prev_cursor_y = cursor_y;
    g_cursor_initialized = 1;
  }

  delta_x = cursor_x - g_prev_cursor_x;
  delta_y = cursor_y - g_prev_cursor_y;
  g_prev_cursor_x = cursor_x;
  g_prev_cursor_y = cursor_y;

  if (glfwGetMouseButton(g_window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS) {
    input_state->mouse_dx = (float)delta_x;
    input_state->mouse_dy = (float)delta_y;
  }

  input_state->seed_step = consume_key_press(GLFW_KEY_2) - consume_key_press(GLFW_KEY_1);
  input_state->symmetry_step = consume_key_press(GLFW_KEY_4) - consume_key_press(GLFW_KEY_3);
  input_state->glyph_step = consume_key_press(GLFW_KEY_6) - consume_key_press(GLFW_KEY_5);
  input_state->pulse_step = consume_key_press(GLFW_KEY_8) - consume_key_press(GLFW_KEY_7);
  input_state->post_toggle = consume_key_press(GLFW_KEY_O);
  input_state->capture_requested = consume_key_press(GLFW_KEY_C);
  input_state->state_requested = consume_key_press(GLFW_KEY_P);
}

void hrf_gl_set_camera_state(
    float position_x,
    float position_y,
    float position_z,
    float yaw,
    float pitch,
    float fov_degrees) {
  g_camera_position[0] = position_x;
  g_camera_position[1] = position_y;
  g_camera_position[2] = position_z;
  g_camera_yaw = yaw;
  g_camera_pitch = pitch;
  g_camera_fov = fov_degrees;
}

void hrf_gl_set_post_parameters(
    int enabled,
    float bloom_strength,
    float vignette_strength,
    float exposure) {
  g_post_enabled = enabled != 0;
  g_post_bloom_strength = bloom_strength;
  g_post_vignette_strength = vignette_strength;
  g_post_exposure = exposure;
}

void hrf_gl_request_capture(const char *output_dir) {
  if (output_dir != NULL && output_dir[0] != '\0') {
    snprintf(g_capture_directory, sizeof(g_capture_directory), "%s", output_dir);
  }
  g_capture_requested = 1;
}

void hrf_gl_set_window_title(const char *title) {
  if (g_window != NULL && title != NULL) {
    glfwSetWindowTitle(g_window, title);
  }
}

void hrf_gl_set_field_texture(int width, int height, const float *field_data) {
  if (g_field_texture == 0 || field_data == NULL || width <= 0 || height <= 0) {
    return;
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glBindTexture(GL_TEXTURE_2D, g_field_texture);

  if (g_field_width != width || g_field_height != height) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, width, height, 0, GL_RED, GL_FLOAT, field_data);
    g_field_width = width;
    g_field_height = height;
  } else {
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RED, GL_FLOAT, field_data);
  }

  glBindTexture(GL_TEXTURE_2D, 0);
}

void hrf_gl_set_relic_parameters(
    int dominant_index,
    int descriptor_count,
    const float *symmetry,
    const float *ring_count,
    const float *glyph_density,
    const float *fracture_amount,
    const float *emissive_hue_bias,
    const float *pulse_speed,
    const float *pulse_intensity,
    const float *center_x,
    const float *center_y,
    const float *region_scale_x,
    const float *region_scale_y,
    const float *region_rotation,
    const float *layer_depth,
    const float *composition_weight,
    const float *overlap_softness,
    const float *pulse_phase) {
  int i = 0;
  int clamped_count = descriptor_count;

  if (clamped_count < 0) {
    clamped_count = 0;
  }
  if (clamped_count > HRF_MAX_RELIC_DESCRIPTORS) {
    clamped_count = HRF_MAX_RELIC_DESCRIPTORS;
  }

  g_relic_count = clamped_count;
  g_dominant_index = dominant_index;
  if (g_dominant_index < 0) {
    g_dominant_index = 0;
  }
  if (g_dominant_index >= g_relic_count && g_relic_count > 0) {
    g_dominant_index = g_relic_count - 1;
  }
  memset(g_relic_symmetry, 0, sizeof(g_relic_symmetry));
  memset(g_relic_ring_count, 0, sizeof(g_relic_ring_count));
  memset(g_relic_glyph_density, 0, sizeof(g_relic_glyph_density));
  memset(g_relic_fracture_amount, 0, sizeof(g_relic_fracture_amount));
  memset(g_relic_emissive_hue_bias, 0, sizeof(g_relic_emissive_hue_bias));
  memset(g_relic_pulse_speed, 0, sizeof(g_relic_pulse_speed));
  memset(g_relic_pulse_intensity, 0, sizeof(g_relic_pulse_intensity));
  memset(g_relic_center_x, 0, sizeof(g_relic_center_x));
  memset(g_relic_center_y, 0, sizeof(g_relic_center_y));
  memset(g_relic_region_scale_x, 0, sizeof(g_relic_region_scale_x));
  memset(g_relic_region_scale_y, 0, sizeof(g_relic_region_scale_y));
  memset(g_relic_region_rotation, 0, sizeof(g_relic_region_rotation));
  memset(g_relic_layer_depth, 0, sizeof(g_relic_layer_depth));
  memset(g_relic_composition_weight, 0, sizeof(g_relic_composition_weight));
  memset(g_relic_overlap_softness, 0, sizeof(g_relic_overlap_softness));
  memset(g_relic_pulse_phase, 0, sizeof(g_relic_pulse_phase));

  for (i = 0; i < clamped_count; ++i) {
    g_relic_symmetry[i] = symmetry[i];
    g_relic_ring_count[i] = ring_count[i];
    g_relic_glyph_density[i] = glyph_density[i];
    g_relic_fracture_amount[i] = fracture_amount[i];
    g_relic_emissive_hue_bias[i] = emissive_hue_bias[i];
    g_relic_pulse_speed[i] = pulse_speed[i];
    g_relic_pulse_intensity[i] = pulse_intensity[i];
    g_relic_center_x[i] = center_x[i];
    g_relic_center_y[i] = center_y[i];
    g_relic_region_scale_x[i] = region_scale_x[i];
    g_relic_region_scale_y[i] = region_scale_y[i];
    g_relic_region_rotation[i] = region_rotation[i];
    g_relic_layer_depth[i] = layer_depth[i];
    g_relic_composition_weight[i] = composition_weight[i];
    g_relic_overlap_softness[i] = overlap_softness[i];
    g_relic_pulse_phase[i] = pulse_phase[i];
  }
}

static void render_scene_pass(int framebuffer_width, int framebuffer_height, float time_seconds) {
  glBindFramebufferPtr(GL_FRAMEBUFFER, g_scene_framebuffer);
  glViewport(0, 0, framebuffer_width, framebuffer_height);
  glClearColor(0.02f, 0.03f, 0.05f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgramPtr(g_program);
  glActiveTexturePtr(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, g_field_texture);
  glUniform1iPtr(g_u_field_texture, 0);
  glUniform2fPtr(
      g_u_field_texel_size,
      g_field_width > 0 ? 1.0f / (float)g_field_width : 1.0f,
      g_field_height > 0 ? 1.0f / (float)g_field_height : 1.0f);
  glUniform2fPtr(g_u_resolution, (float)framebuffer_width, (float)framebuffer_height);
  glUniform1fPtr(g_u_time, time_seconds);
  glUniform1iPtr(g_u_relic_count, g_relic_count);
  glUniform1iPtr(g_u_dominant_index, g_dominant_index);
  glUniform1fvPtr(g_u_symmetry, HRF_MAX_RELIC_DESCRIPTORS, g_relic_symmetry);
  glUniform1fvPtr(g_u_ring_count, HRF_MAX_RELIC_DESCRIPTORS, g_relic_ring_count);
  glUniform1fvPtr(g_u_glyph_density, HRF_MAX_RELIC_DESCRIPTORS, g_relic_glyph_density);
  glUniform1fvPtr(g_u_fracture_amount, HRF_MAX_RELIC_DESCRIPTORS, g_relic_fracture_amount);
  glUniform1fvPtr(g_u_emissive_hue_bias, HRF_MAX_RELIC_DESCRIPTORS, g_relic_emissive_hue_bias);
  glUniform1fvPtr(g_u_pulse_speed, HRF_MAX_RELIC_DESCRIPTORS, g_relic_pulse_speed);
  glUniform1fvPtr(g_u_pulse_intensity, HRF_MAX_RELIC_DESCRIPTORS, g_relic_pulse_intensity);
  glUniform1fvPtr(g_u_center_x, HRF_MAX_RELIC_DESCRIPTORS, g_relic_center_x);
  glUniform1fvPtr(g_u_center_y, HRF_MAX_RELIC_DESCRIPTORS, g_relic_center_y);
  glUniform1fvPtr(g_u_region_scale_x, HRF_MAX_RELIC_DESCRIPTORS, g_relic_region_scale_x);
  glUniform1fvPtr(g_u_region_scale_y, HRF_MAX_RELIC_DESCRIPTORS, g_relic_region_scale_y);
  glUniform1fvPtr(g_u_region_rotation, HRF_MAX_RELIC_DESCRIPTORS, g_relic_region_rotation);
  glUniform1fvPtr(g_u_layer_depth, HRF_MAX_RELIC_DESCRIPTORS, g_relic_layer_depth);
  glUniform1fvPtr(g_u_composition_weight, HRF_MAX_RELIC_DESCRIPTORS, g_relic_composition_weight);
  glUniform1fvPtr(g_u_overlap_softness, HRF_MAX_RELIC_DESCRIPTORS, g_relic_overlap_softness);
  glUniform1fvPtr(g_u_pulse_phase, HRF_MAX_RELIC_DESCRIPTORS, g_relic_pulse_phase);
  glUniform3fPtr(
      g_u_camera_position,
      g_camera_position[0],
      g_camera_position[1],
      g_camera_position[2]);
  glUniform1fPtr(g_u_camera_yaw, g_camera_yaw);
  glUniform1fPtr(g_u_camera_pitch, g_camera_pitch);
  glUniform1fPtr(g_u_camera_fov, g_camera_fov);
  glBindVertexArrayPtr(g_vertex_array);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArrayPtr(0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glUseProgramPtr(0);
}

static void render_post_pass(int framebuffer_width, int framebuffer_height, float time_seconds) {
  glBindFramebufferPtr(GL_FRAMEBUFFER, 0);
  glViewport(0, 0, framebuffer_width, framebuffer_height);
  glClearColor(0.01f, 0.01f, 0.02f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgramPtr(g_post_program);
  glActiveTexturePtr(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, g_scene_color_texture);
  glUniform1iPtr(g_u_post_scene_texture, 0);
  glUniform2fPtr(g_u_post_resolution, (float)framebuffer_width, (float)framebuffer_height);
  glUniform1fPtr(g_u_post_time, time_seconds);
  glUniform1iPtr(g_u_post_enabled, g_post_enabled);
  glUniform1fPtr(g_u_post_bloom_strength, g_post_bloom_strength);
  glUniform1fPtr(g_u_post_vignette_strength, g_post_vignette_strength);
  glUniform1fPtr(g_u_post_exposure, g_post_exposure);
  glBindVertexArrayPtr(g_vertex_array);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArrayPtr(0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glUseProgramPtr(0);
}

void hrf_gl_render_frame(float time_seconds) {
  int framebuffer_width = 0;
  int framebuffer_height = 0;

  if (g_window == NULL || g_program == 0 || g_vertex_array == 0) {
    return;
  }

  glfwGetFramebufferSize(g_window, &framebuffer_width, &framebuffer_height);
  if (framebuffer_width <= 0 || framebuffer_height <= 0) {
    return;
  }

  if (!ensure_scene_framebuffer(framebuffer_width, framebuffer_height)) {
    return;
  }

  render_scene_pass(framebuffer_width, framebuffer_height, time_seconds);
  render_post_pass(framebuffer_width, framebuffer_height, time_seconds);
  capture_framebuffer_if_requested(framebuffer_width, framebuffer_height);
}

void hrf_gl_poll_events(void) {
  glfwPollEvents();
}

void hrf_gl_swap_buffers(void) {
  if (g_window != NULL) {
    glfwSwapBuffers(g_window);
  }
}

void hrf_gl_shutdown(void) {
  destroy_renderer();

  if (g_window != NULL) {
    glfwDestroyWindow(g_window);
    g_window = NULL;
  }

  glfwTerminate();
}
