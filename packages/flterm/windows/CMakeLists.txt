cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flterm")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "flterm_plugin")

add_library(${PLUGIN_NAME} SHARED
  "include/flterm/flterm_plugin_c_api.h"
  "flterm_plugin.cpp"
  "flterm_plugin.h"
  "flterm_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  Comctl32.lib
)

set(flterm_bundled_libraries "" PARENT_SCOPE)
