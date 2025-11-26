cmake_minimum_required(VERSION 3.8)
project(robot_to_main_comm_node)

# Default to C++17
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(std_srvs REQUIRED)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

# Create executable
add_executable(robot_to_main_comm_node src/robot_to_main_comm_node.cpp)

# Configure dependencies
#target_include_directories(robot_to_main_comm_node PUBLIC
  #$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
 # $<INSTALL_INTERFACE:include>)

ament_target_dependencies(robot_to_main_comm_node
  rclcpp
  std_msgs
  std_srvs
)

# Install executables
install(TARGETS
  robot_to_main_comm_node
  DESTINATION lib/${PROJECT_NAME}
)

# Install include directories
#install(DIRECTORY include/
#  DESTINATION include
#)

ament_package()
