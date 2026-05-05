#include "primitive_to_clips/primitive_to_clips_node.hpp"
#include "primitive_to_clips/clips_fact_factory.hpp"
#include <cstddef>
#include <memory>
#include <rclcpp/executors/single_threaded_executor.hpp>

// ─────────────────────────────────────────────────────────────────────────────
// Constructor / Destructor / init
// ─────────────────────────────────────────────────────────────────────────────

PrimitiveToClipsNode::PrimitiveToClipsNode() : Node("primitive_to_clips") {

  service_ = create_service<StringSrv>(
      "primitive_to_clips/convert",
      std::bind(&PrimitiveToClipsNode::handle_convert, this,
                std::placeholders::_1, std::placeholders::_2));

  rclcpp::NodeOptions client_opts;
  client_opts.use_global_arguments(false);
  client_node_ =
      rclcpp::Node::make_shared("primitive_to_clips_clients", client_opts);

  assert_client_ =
      client_node_->create_client<StringArray>("clips/assert_facts_batch");
  planning_client_ =
      client_node_->create_client<Trigger>("clips/start_planning");

  client_executor_ =
      std::make_unique<rclcpp::executors::SingleThreadedExecutor>();
  client_executor_->add_node(client_node_);

  RCLCPP_INFO(get_logger(), "Primitive_to_clips node ready.");
}

PrimitiveToClipsNode::~PrimitiveToClipsNode() {}

void PrimitiveToClipsNode::init() {
  // Called from main() after make_shared — shared_from_this() is valid here.
  // WorldStateClient receives client_node_ (already in client_executor_)
  // so it can wait on futures without any add_node calls.
  world_client_ =
      std::make_shared<WorldStateClient>(client_node_, *client_executor_);
}

// ─────────────────────────────────────────────────────────────────────────────
// Service callback
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
      ++step;
    } catch (const std::exception &e) {
      RCLCPP_ERROR(get_logger(), "Factory error: %s", e.what());
    }
  }

  return facts;
}

// ─────────────────────────────────────────────────────────────────────────────
// Client calls — use client_executor_ (background thread), not *this*
// ─────────────────────────────────────────────────────────────────────────────

bool PrimitiveToClipsNode::assert_facts(const std::vector<std::string> &facts) {
  if (!assert_client_->wait_for_service(std::chrono::seconds(3))) {
    RCLCPP_ERROR(get_logger(), "assert_facts_batch service not available.");
    return false;
  }

  auto req = std::make_shared<StringArray::Request>();
  req->data = facts;
  auto future = assert_client_->async_send_request(req);

  // client_executor_ already spins client_node_ on client_thread_,
  // so the future will be completed there — just block until done.
  return client_executor_->spin_until_future_complete(future) ==
         rclcpp::FutureReturnCode::SUCCESS;
}

bool PrimitiveToClipsNode::trigger_planning() {
  if (!planning_client_->wait_for_service(std::chrono::seconds(3))) {
    RCLCPP_ERROR(get_logger(), "start_planning service not available.");
    return false;
  }

  auto future = planning_client_->async_send_request(
      std::make_shared<Trigger::Request>());

  return client_executor_->spin_until_future_complete(future) ==
         rclcpp::FutureReturnCode::SUCCESS;
}
