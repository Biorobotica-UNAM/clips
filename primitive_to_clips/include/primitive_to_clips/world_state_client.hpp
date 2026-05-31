#pragma once

#include <knowledge_interfaces/srv/get_world_state.hpp>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <memory>
#include <nlohmann/json.hpp>
#include <rclcpp/client.hpp>
#include <rclcpp/executors.hpp>
#include <rclcpp/future_return_code.hpp>
#include <rclcpp/logging.hpp>
#include <rclcpp/node.hpp>
#include <rclcpp/rclcpp.hpp>
#include <string>
#include <vector>

class WorldStateClient {
public:
  // node     — sibling client_node_ (NOT the main spinning node)
  // executor — the executor already spinning node on its own thread
  WorldStateClient(rclcpp::Node::SharedPtr node,
                   rclcpp::executors::SingleThreadedExecutor &executor);

  std::vector<std::string> load();

private:
  using GetWorldState = knowledge_interfaces::srv::GetWorldState;

  rclcpp::Node::SharedPtr node_;
  rclcpp::executors::SingleThreadedExecutor &executor_;
  rclcpp::Client<GetWorldState>::SharedPtr client_;

  std::vector<std::string> json_to_facts(const std::string &json_str);
  std::vector<std::string> build_robot_fact(const nlohmann::json &robot);
  std::vector<std::string> build_object_facts(const nlohmann::json &objects);
  std::vector<std::string> build_people_facts(const nlohmann::json &people);
  std::string sym(const nlohmann::json &value);
};
