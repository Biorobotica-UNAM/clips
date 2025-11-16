cmake_minimum_required(VERSION 3.8)
project(clips_client_cpp)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(custom_interfaces REQUIRED)
find_package(std_srvs REQUIRED)

# Crear la biblioteca
add_library(clips_client_lib
  src/clips_client_lib.cpp
)

# Especificar includes públicos
target_include_directories(clips_client_lib PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)

# Dependencias
ament_target_dependencies(clips_client_lib 
  rclcpp 
  custom_interfaces 
  std_srvs
)

# Instalar la biblioteca y headers
install(TARGETS clips_client_lib
  EXPORT export_${PROJECT_NAME}
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)

install(DIRECTORY include/
  DESTINATION include
)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_export_include_directories(include)
ament_export_libraries(clips_client_lib)
ament_export_dependencies(rclcpp custom_interfaces std_srvs)

ament_package()