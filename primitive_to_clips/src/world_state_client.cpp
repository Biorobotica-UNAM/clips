#include "primitive_to_clips/world_state_client.hpp"
#include <string>
#include <vector>

WorldStateClient::WorldStateClient(rclcpp::Node::SharedPtr node) : node_{node} {
  client_ = node_->create_client<GetWorldState>("/world/get_state");
}

std::vector<std::string> WorldStateClient::load() {
  if (!client_->wait_for_service(std::chrono::seconds(3))) {
    RCLCPP_WARN(node_->get_logger(),
                "/world/get_state not available. Using empty world.");

    return {};
  }

  auto request = std::make_shared<GetWorldState::Request>();
  auto future = client_->async_send_request(request);

  if (rclcpp::spin_until_future_complete(node_, future) !=
      rclcpp::FutureReturnCode::SUCCESS) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to call world state service.");

    return {};
  }

  auto response = future.get();
  return json_to_facts(response->json);
}

std::vector<std::string>
WorldStateClient::json_to_facts(const std::string &json_str) {
  std::vector<std::string> facts{};

  try {
    auto data = nlohmann::json::parse(json_str);
    auto robot =
        build_robot_fact(data.value("robot", nlohmann::json::object()));
    auto objects =
        build_object_facts(data.value("objects", nlohmann::json::array()));

    facts.insert(facts.end(), robot.begin(), robot.end());
    facts.insert(facts.end(), objects.begin(), objects.end());

  } catch (...) {
    RCLCPP_ERROR(node_->get_logger(), "Invalid JSON from world state.");
  }

  return facts;
}

std::vector<std::string>
WorldStateClient::build_robot_fact(const nlohmann::json &robot) {
  if (robot.empty()) {
    return {};
  }

  std::string room = sym(robot.value("room", "unknown"));
  std::string holding = sym(robot.value("holding", "nothing"));

  return {"(robot-state (room " + room + ") (holding " + holding + "))"};
}

std::vector<std::string>
WorldStateClient::build_object_facts(const nlohmann::json &objects) {
  std::vector<std::string> facts{};

  for (const auto &obj : objects) {
    std::string name = sym(obj.value("name", "unknown"));
    std::string room = sym(obj.value("room", "unknown"));
    facts.push_back("(object-state (name " + name + ") (room " + room + "))");
  }

  return facts;
}

std::string WorldStateClient::sym(const nlohmann::json &value) {
  if (value.is_null())
    return "unknown";

  std::string s = value.get<std::string>();
  std::transform(s.begin(), s.end(), s.begin(), ::tolower);
  std::replace(s.begin(), s.end(), ' ', '_');

  return s.empty() ? "unknown" : s;
}
