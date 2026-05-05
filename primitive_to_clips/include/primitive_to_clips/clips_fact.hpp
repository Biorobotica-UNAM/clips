#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <utility>
#include <vector>

using Slot = std::pair<std::string, std::string>;

class ClipsFact {
public:
  virtual ~ClipsFact() = default;

  std::string build(int step, const nlohmann::json &primitive);

protected:
  virtual std::vector<Slot> extract_slots(const nlohmann::json &primitive) = 0;

  std::vector<Slot> base_slots(const nlohmann::json &primitive);

  std::string get_sym(const nlohmann::json &j, const std::string &key);

  std::string get_entity(const nlohmann::json &j, const std::string &key);

  void flatten_object(const nlohmann::json &j, const std::string &prefix,
                      std::vector<Slot> &slots) const;

private:
  std::string format_fact(int step, const std::vector<Slot> &slots);

  std::string sym(const nlohmann::json &value) const;

  std::string entity(const nlohmann::json &value) const;

  std::string get(const nlohmann::json &obj, const std::string &key,
                  const std::string &default_vaule = "unknown") const;
};
