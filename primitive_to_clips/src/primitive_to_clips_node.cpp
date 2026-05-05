#include "primitive_to_clips/primitive_to_clips_node.hpp"
#include "primitive_to_clips/clips_fact_factory.hpp"
#include <cstddef>

PrimitiveToClipsNode::PrimitiveToClipsNode() : Node("primitive_to_clips") {
  world_client_ = std::make_shared<WorldStateClient>(shared_from_this());

  service_ = create_service<StringSrv>(
      "primitive_to_clips/convert",
      std::bind(&PrimitiveToClipsNode::handle_convert, this,
                std::placeholders::_1, std::placeholders::_2));

  assert_client_ = create_client<StringArray>("clips/assert_facts_batch");

  planning_client_ = create_client<Trigger>("clips/start_planning");

  RCLCPP_INFO(get_logger(), "Primitive_to_clips node ready.");
}

void PrimitiveToClipsNode::handle_convert(
    const std::shared_ptr<StringSrv::Request> request,
    std::shared_ptr<StringSrv::Response> response) {

  auto primitives = parse_request(request->data);

  if (primitives.empty()) {
    response->data = "ERROR: invalid JSON";
    return;
  }

  auto world_facts = world_client_->load();
  auto primitive_facts = build_primitive_facts(primitives);

  std::vector<std::string> all_facts = world_facts;
  all_facts.insert(all_facts.end(), primitive_facts.begin(),
                   primitive_facts.end());

  RCLCPP_INFO(get_logger(), "==== CLIPS FACTS ====");
  for (size_t i{0}; i < all_facts.size(); ++i) {
    RCLCPP_INFO(get_logger(), "[%zu] %s", i + 1, all_facts[i].c_str());
  }

  RCLCPP_INFO(get_logger(), "=========================");

  if (!assert_facts(all_facts)) {
    response->data = "ERROR asserting facts";
    return;
  }

  if (!trigger_planning()) {
    response->data = "ERROR triggering planning.";
    return;
  }

  response->data = "OK";
}

std::vector<nlohmann::json>
PrimitiveToClipsNode::parse_request(const std::string &data) {
  try {
    auto json = nlohmann::json::parse(data);
    std::vector<nlohmann::json> result{};
    for (auto &p : json) {
      result.push_back(p);
    }
    return result;

  } catch (...) {
    RCLCPP_ERROR(get_logger(), "JSON PARSER error");
    return {};
  }
}

std::vector<std::string> PrimitiveToClipsNode::build_primitive_facts(
    const std::vector<nlohmann::json> &primitives) {
  std::vector<std::string> facts;

  int step{1};

  for (const auto &p : primitives) {
    std::string type = p.value("primitive", "DO");

    try {
      auto builder = factory_.create(type);
      facts.push_back(builder->build(step, p));

    } catch (const std::exception &e) {
      RCLCPP_ERROR(get_logger(), "Factory error %s", e.what());
    }
  }

  return facts;
}

bool PrimitiveToClipsNode::assert_facts(const std::vector<std::string> &facts) {
  if (!assert_client_->wait_for_service(std::chrono::seconds(3))) {
    return false;
  }

  auto req = std::make_shared<StringArray::Request>();
  req->data = facts;

  auto future = assert_client_->async_send_request(req);

  return rclcpp::spin_until_future_complete(shared_from_this(), future) ==
         rclcpp::FutureReturnCode::SUCCESS;
}

bool PrimitiveToClipsNode::trigger_planning() {
  if (!planning_client_->wait_for_service(std::chrono::seconds(3))) {
    return false;
  }

  auto future = planning_client_->async_send_request(
      std::make_shared<Trigger::Request>());

  return rclcpp::spin_until_future_complete(shared_from_this(), future) ==
         rclcpp::FutureReturnCode::SUCCESS;
}
