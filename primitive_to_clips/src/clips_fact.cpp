#include "primitive_to_clips/clips_fact.hpp"
#include <algorithm>
#include <cctype>
#include <map>
#include <string>

namespace {
std::string trim(const std::string &s) {
  const auto begin = std::find_if_not(s.begin(), s.end(), ::isspace);
  const auto end = std::find_if_not(s.rbegin(), s.rend(), ::isspace).base();

  return (begin < end) ? std::string(begin, end) : "";
}

std::string to_lower(const std::string &s) {
  std::string result{s};

  std::transform(result.begin(), result.end(), result.begin(),
                 [](unsigned char c) { return std::tolower(c); });

  return result;
}

} // namespace

std::string ClipsFact::build(int step, const nlohmann::json &primitive) {
  auto slots = extract_slots(primitive);
  return format_fact(step, slots);
}

std::vector<Slot> ClipsFact::base_slots(const nlohmann::json &p) {
  std::vector<Slot> slots;

  slots.emplace_back("primitive", sym(p.value("primitive", "UNKNOWN")));
  slots.emplace_back("actor", sym(p.value("actor", "robot")));

  return slots;
}

std::string ClipsFact::get_sym(const nlohmann::json &j,
                               const std::string &key) {
  return sym(get(j, key));
}

std::string ClipsFact::get_entity(const nlohmann::json &j,
                                  const std::string &key) {
  return entity(get(j, key));
}

void ClipsFact::flatten_object(const nlohmann::json &j,
                               const std::string &prefix,
                               std::vector<Slot> &slots) const {

  for (auto it = j.begin(); it != j.end(); ++it) {

    std::string key = prefix.empty() ? it.key() : prefix + "_" + it.key();

    if (it->is_object()) {
      flatten_object(*it, key, slots);
    } else {
      slots.emplace_back(key, sym(*it));
    }
  }
}

std::string ClipsFact::format_fact(int step, const std::vector<Slot> &slots) {

  std::string fact = "(cd-primitive (step " + std::to_string(step) + ")";

  for (const auto &[key, value] : slots) {
    fact += " (" + key + " " + value + ")";
  }

  fact += ")";
  return fact;
}

std::string ClipsFact::sym(const nlohmann::json &value) const {
  if (value.is_null())
    return "unknown";

  std::string raw;

  if (value.is_string()) {
    raw = trim(value.get<std::string>());
    if (raw.empty() || to_lower(raw) == "unknown")
      return "unknown";
  } else {
    raw = value.dump();
  }

  std::string lower = to_lower(trim(raw));
  std::replace(lower.begin(), lower.end(), ' ', '_');

  return lower;
}

std::string ClipsFact::entity(const nlohmann::json &value) const {
  std::string s = sym(value);

  if (s == "unknown")
    return s;

  for (const std::string prefix : {"the_", "an_", "a_"}) {
    if (s.rfind(prefix, 0) == 0)
      return s.substr(prefix.size());
  }

  return s;
}

std::string ClipsFact::get(const nlohmann::json &obj, const std::string &key,
                           const std::string &default_vaule) const {
  return obj.value(key, default_vaule);
}
