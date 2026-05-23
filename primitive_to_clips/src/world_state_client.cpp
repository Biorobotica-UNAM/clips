#include "primitive_to_clips/world_state_client.hpp"
#include <string>
#include <vector>

WorldStateClient::WorldStateClient(
    rclcpp::Node::SharedPtr node,
    rclcpp::executors::SingleThreadedExecutor &executor)
    : node_{node}, executor_{executor} {
  client_ = node_->create_client<GetWorldState>(
      "/knowledge/knowledge_manager/world/get_state");
}

std::vector<std::string> WorldStateClient::load() {
  if (!client_->wait_for_service(std::chrono::seconds(3))) {
    RCLCPP_WARN(node_->get_logger(), "/world/get_state not available. "
                                     "Using empty world.");
    return {};
  }

  auto request = std::make_shared<GetWorldState::Request>();

  request->category = "world";
  request->id = "";
  request->attribute = "";

  auto future = client_->async_send_request(request);

  // executor_ is already spinning node_ on a background thread —
  // just wait on the future, no add_node needed.
  if (executor_.spin_until_future_complete(future) !=
      rclcpp::FutureReturnCode::SUCCESS) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to call world state service.");
    return {};
  }

  return json_to_facts(future.get()->json);
}

std::vector<std::string>
WorldStateClient::json_to_facts(const std::string &json_str) {
  std::vector<std::string> facts{};

  try {
    auto data = nlohmann::json::parse(json_str);

    //
    // ROBOT
    //
    auto robot_facts =
        build_robot_fact(data.value("robot", nlohmann::json::object()));

    facts.insert(facts.end(), robot_facts.begin(), robot_facts.end());

    //
    // OBJECTS
    //
    nlohmann::json objects = nlohmann::json::array();

    if (data.contains("objects") && data["objects"].contains("objects")) {
      objects = data["objects"]["objects"];
    }

    auto object_facts = build_object_facts(objects);

    facts.insert(facts.end(), object_facts.begin(), object_facts.end());

    //
    // PEOPLE
    //
    nlohmann::json people = nlohmann::json::array();

    if (data.contains("people") && data["people"].contains("people")) {
      people = data["people"]["people"];
    }

    auto people_facts = build_people_facts(people);

    facts.insert(facts.end(), people_facts.begin(), people_facts.end());

    //
    // KNOWN LOCATIONS
    //
    nlohmann::json known_locations = nlohmann::json::object();

    if (data.contains("known_locations")) {
      known_locations = data["known_locations"];
    }

    auto location_facts = build_location_facts(known_locations);

    facts.insert(facts.end(), location_facts.begin(), location_facts.end());
  } catch (const std::exception &e) {
    RCLCPP_ERROR(node_->get_logger(), "Invalid JSON from world state: %s",
                 e.what());
  }

  return facts;
}

std::vector<std::string>
WorldStateClient::build_robot_fact(const nlohmann::json &robot) {
  if (robot.empty())
    return {};
  std::string name = sym(robot.value("name", "unknown"));
  std::string room = sym(robot.value("location", "unknown"));
  std::string left_hand = sym(robot.value("left_hand", "nothing"));
  std::string right_hand = sym(robot.value("right_hand", "nothing"));
  return {"(robot-state (name " + name + ") (room " + room + ") (left_hand " +
          left_hand + ") (right_hand " + right_hand + "))"};
}

std::vector<std::string>
WorldStateClient::build_object_facts(const nlohmann::json &objects) {
  std::vector<std::string> facts{};

  for (const auto &obj : objects) {
    std::string name = sym(obj.value("name", "unknown"));

    // Obtener arreglo de locations
    if (obj.contains("locations") && obj["locations"].is_array() &&
        !obj["locations"].empty()) {
      for (const auto &loc : obj["locations"]) {
        std::string room = sym(loc.get<std::string>());

        facts.push_back("(object-state "
                        "(name " +
                        name +
                        ") "
                        "(room " +
                        room + "))");
      }
    } else {
      // Sin ubicación conocida
      facts.push_back("(object-state "
                      "(name " +
                      name +
                      ") "
                      "(room unknown))");
    }
  }

  return facts;
}

std::vector<std::string>
WorldStateClient::build_location_facts(const nlohmann::json &locations_json) {
  std::vector<std::string> facts{};

  if (!locations_json.contains("known_locations"))
    return facts;

  const auto &locations = locations_json["known_locations"];

  if (!locations.is_array())
    return facts;

  for (const auto &loc : locations) {
    std::string name = sym(loc.get<std::string>());

    facts.push_back("(known-location "
                    "(name " +
                    name + "))");
  }

  return facts;
}

std::vector<std::string>
WorldStateClient::build_people_facts(const nlohmann::json &people_json) {
  std::vector<std::string> facts{};

  if (!people_json.contains("people"))
    return facts;

  const auto &people = people_json["people"];

  if (!people.is_array())
    return facts;

  for (const auto &person : people) {
    std::string name = sym(person.value("name", "unknown"));

    std::string room = sym(person.value("room", "unknown"));

    std::string gender = sym(person.value("gender", "unknown"));

    std::string age_group = sym(person.value("age_group", "unknown"));

    std::string emotion = sym(person.value("emotion", "unknown"));

    std::string hair_color = sym(person.value("hair_color", "unknown"));

    std::string hair_style = sym(person.value("hair_style", "unknown"));

    std::string shirt_color = sym(person.value("shirt_color", "unknown"));

    std::string accessories_str{};

    if (person.contains("accessories") && person["accessories"].is_array()) {
      for (const auto &acc : person["accessories"]) {
        accessories_str += sym(acc.get<std::string>()) + " ";
      }
    }

    facts.push_back("(person-state "
                    "(name " +
                    name +
                    ") "
                    "(room " +
                    room +
                    ") "
                    "(gender " +
                    gender +
                    ") "
                    "(age_group " +
                    age_group +
                    ") "
                    "(emotion " +
                    emotion +
                    ") "
                    "(hair_color " +
                    hair_color +
                    ") "
                    "(hair_style " +
                    hair_style +
                    ") "
                    "(shirt_color " +
                    shirt_color +
                    ") "
                    "(accessories " +
                    accessories_str + "))");
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
