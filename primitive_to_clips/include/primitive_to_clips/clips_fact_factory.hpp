#pragma once

#include "primitive_to_clips/clips_fact.hpp"
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>

class ClipsFactFactory {
public:
  using Creator = std::function<std::unique_ptr<ClipsFact>()>;

  static void register_type(const std::string &type, Creator creator);

  static std::unique_ptr<ClipsFact> create(const std::string &type);

private:
  static std::unordered_map<std::string, Creator> &registry;
};
