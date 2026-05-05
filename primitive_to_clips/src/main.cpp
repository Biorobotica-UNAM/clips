#include "primitive_to_clips/primitive_to_clips_node.hpp"
#include <memory>
#include <rclcpp/executors.hpp>
#include <rclcpp/rclcpp.hpp>

int main(int argc, char **argv) {
  rclcpp::init(argc, argv);

  auto node = std::make_shared<PrimitiveToClipsNode>();
  node->init();

  auto executor = std::make_shared<rclcpp::executors::MultiThreadedExecutor>(
      rclcpp::ExecutorOptions(), 2);
  executor->add_node(node);
  executor->spin();

  rclcpp::shutdown();
  return 0;
}
