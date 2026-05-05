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
#include <thread>
#include <vector>

#include "primitive_to_clips/clips_fact_factory.hpp"
#include "primitive_to_clips/world_state_client.hpp"

class PrimitiveToClipsNode : public rclcpp::Node {
public:
  PrimitiveToClipsNode();
  ~PrimitiveToClipsNode();

  // Must be called once after make_shared — safe to call shared_from_this()
  void init();

private:
  using StringSrv = clips_interfaces::srv::String;
  using StringArray = clips_interfaces::srv::StringArray;
  using Trigger = std_srvs::srv::Trigger;

  ClipsFactFactory factory_;
  std::shared_ptr<WorldStateClient> world_client_;

  // Dedicated node + executor + thread for all outgoing client calls.
  //
  // handle_convert() runs inside a service callback, which means *this*
  // is already owned by the main executor (rclcpp::spin in main.cpp).
  // Calling spin_until_future_complete(shared_from_this(), future) from
  // inside that callback throws "node already added to executor".
  //
  // Solution: a lightweight sibling node (client_node_) lives in its own
  // SingleThreadedExecutor on a background thread.  All outgoing clients
  // are created on client_node_ and waited on via client_executor_.
  rclcpp::Node::SharedPtr client_node_;
  rclcpp::executors::SingleThreadedExecutor::UniquePtr client_executor_;
  std::thread client_thread_;

  // Service on *this*; clients on client_node_
  rclcpp::Service<StringSrv>::SharedPtr service_;
  rclcpp::Client<StringArray>::SharedPtr assert_client_;
  rclcpp::Client<Trigger>::SharedPtr planning_client_;

  void handle_convert(const std::shared_ptr<StringSrv::Request> request,
                      std::shared_ptr<StringSrv::Response> response);

  std::vector<nlohmann::json> parse_request(const std::string &data);
  std::vector<std::string>
  build_primitive_facts(const std::vector<nlohmann::json> &primitives);

  bool assert_facts(const std::vector<std::string> &facts);
  bool trigger_planning();
};
