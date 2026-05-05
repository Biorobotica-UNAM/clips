#include "primitive_to_clips/primitive_to_clips_node.hpp"
#include <rclcpp/rclcpp.hpp>

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);

  auto node = std::make_shared<PrimitiveToClipsNode>();

  rclcpp::spin(node);
  rclcpp::shutdown();

  return 0;
}
