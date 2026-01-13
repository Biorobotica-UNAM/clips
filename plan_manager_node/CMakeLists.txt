cmake_minimum_required(VERSION 3.8)
project(plan_manager_node)

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

# Find Boost
find_package(Boost REQUIRED COMPONENTS system)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

# Create executable
add_executable(plan_manager_node src/plan_manager_node.cpp)

# Configure dependencies
target_include_directories(plan_manager_node PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
  
target_link_libraries(plan_manager_node
  ${rclcpp_LIBRARIES}
  ${Boost_LIBRARIES}
)

ament_target_dependencies(plan_manager_node
  rclcpp
  std_msgs
  std_srvs
)

# Install executables
install(TARGETS
  plan_manager_node
  DESTINATION lib/${PROJECT_NAME}
)

# Install include directories
#install(DIRECTORY include/
#  DESTINATION include
#)

# Export dependencies
ament_export_include_directories(include)
ament_export_libraries(plan_manager_node)
ament_export_dependencies(rclcpp std_msgs)

ament_package()