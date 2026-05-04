cmake_minimum_required(VERSION 3.8)
project(primitive_to_clips)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(knowledge_interfaces REQUIRED)
find_package(clips_interfaces REQUIRED)
find_package(nlohmann_json REQUIRED)

add_executable(primitive_to_clips_node src/primitive_to_clips_node.cpp)

target_include_directories(primitive_to_clips_node PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include/${PROJECT_NAME}>)

target_compile_features(primitive_to_clips_node PUBLIC
  c_std_99 cxx_std_17)

ament_target_dependencies(
  primitive_to_clips_node
  "rclcpp"
  "knowledge_interfaces"
  "clips_interfaces"
  "nlohmann_json"
)

install(TARGETS primitive_to_clips_node
  DESTINATION lib/${PROJECT_NAME})

install(DIRECTORY include/
  DESTINATION include/${PROJECT_NAME})

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
