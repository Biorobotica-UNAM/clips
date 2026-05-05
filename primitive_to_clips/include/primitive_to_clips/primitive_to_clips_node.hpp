#pragma once

#include <rclcpp/client.hpp>
#include <rclcpp/executors.hpp>
#include <rclcpp/future_return_code.hpp>
#include <rclcpp/logging.hpp>
#include <rclcpp/node.hpp>
#include <rclcpp/rclcpp.hpp>

#include <clips_interfaces/srv/string.hpp>
#include <clips_interfaces/srv/string_array.hpp>
#include <rclcpp/service.hpp>
#include <std_srvs/srv/trigger.hpp>

#include <chrono>
#include <exception>
#include <functional>
#include <memory>
#include <nlohmann/json.hpp>
#include <string>
#include <vector>

#include "primitive_to_clips/clips_fact_factory.hpp"
#include "primitive_to_clips/world_state_client.hpp"

class PrimitiveToClipsNode : public rclcpp::Node {
public:
  PrimitiveToClipsNode();

private:
  using StringSrv = clips_interfaces::srv::String;
  using StringArray = clips_interfaces::srv::StringArray;
  using Trigger = std_srvs::srv::Trigger;

  // Factory
  ClipsFactFactory factory_;

  // World Client
  std::shared_ptr<WorldStateClient> world_client_;

  // ROS interfaces
  rclcpp::Service<StringSrv>::SharedPtr service_;
  rclcpp::Client<StringArray>::SharedPtr assert_client_;
  rclcpp::Client<Trigger>::SharedPtr planning_client_;

  // Callback
  void handle_convert(const std::shared_ptr<StringSrv::Request> request,
                      std::shared_ptr<StringSrv::Response> response);

  // Helpers
  std::vector<nlohmann::json> parse_request(const std::string &data);
  std::vector<std::string>
  build_primitive_facts(const std::vector<nlohmann::json> &facts);

  bool assert_facts(const std::vector<std::string> &facts);
  bool trigger_planning();
};
