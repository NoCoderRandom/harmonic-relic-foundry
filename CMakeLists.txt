cmake_minimum_required(VERSION 3.20)

project(
  HarmonicRelicFoundry
  VERSION 0.1.0
  DESCRIPTION "Procedural relic ecology exploration in Modern Fortran"
  LANGUAGES C Fortran
)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(OpenGL REQUIRED)
find_package(glfw3 REQUIRED)

add_executable(
  harmonic_relic_foundry
  src/main.f90
  src/relic_rules.f90
  src/relic_state.f90
  src/exploration_controls.f90
  src/field_simulation.f90
  src/platform_gl.f90
  src/gl_bridge.c
)

target_link_libraries(
  harmonic_relic_foundry
  PRIVATE
    glfw
    OpenGL::GL
)

target_compile_features(harmonic_relic_foundry PRIVATE c_std_99)

message(STATUS "Configuring ${PROJECT_NAME} ${PROJECT_VERSION}")
