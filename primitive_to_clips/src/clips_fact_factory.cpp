#include "primitive_to_clips/clips_fact_factory.hpp"

#include "primitive_to_clips/clips_facts.hpp"

#include <stdexcept>

std::unordered_map<std::string, ClipsFactFactory::Creator> &
ClipsFactFactory::registry() {

  static std::unordered_map<std::string, Creator> instance;
  return instance;
}

void ClipsFactFactory::register_type(const std::string &type, Creator creator) {
  registry()[type] = std::move(creator);
}

std::unique_ptr<ClipsFact> ClipsFactFactory::create(const std::string &type) {

  auto it = registry().find(type);

  if (it == registry().end()) {
    throw std::runtime_error("Unknown primitive: " + type);
  }

  return it->second();
}

namespace {

// Movement
bool reg_ptrans = [] {
  ClipsFactFactory::register_type(
      "PTRANS", [] { return std::make_unique<PtransFact>(); });
  return true;
}();

bool reg_accompany = [] {
  ClipsFactFactory::register_type(
      "ACCOMPANY", [] { return std::make_unique<AccompanyFact>(); });
  return true;
}();

// Manipulation
bool reg_grasp = [] {
  ClipsFactFactory::register_type("GRASP",
                                  [] { return std::make_unique<GraspFact>(); });
  return true;
}();

bool reg_atrans = [] {
  ClipsFactFactory::register_type(
      "ATRANS", [] { return std::make_unique<AtransFact>(); });
  return true;
}();

// Perception
bool reg_attend = [] {
  ClipsFactFactory::register_type(
      "ATTEND", [] { return std::make_unique<AttendFact>(); });
  return true;
}();

bool reg_query = [] {
  ClipsFactFactory::register_type("QUERY",
                                  [] { return std::make_unique<QueryFact>(); });
  return true;
}();

// Communication
bool reg_mtrans = [] {
  ClipsFactFactory::register_type(
      "MTRANS", [] { return std::make_unique<MtransFact>(); });
  return true;
}();

bool reg_speak = [] {
  ClipsFactFactory::register_type("SPEAK",
                                  [] { return std::make_unique<SpeakFact>(); });
  return true;
}();

// Social
bool reg_social = [] {
  ClipsFactFactory::register_type(
      "SOCIAL", [] { return std::make_unique<SocialFact>(); });
  return true;
}();

// Wait
bool reg_wait = [] {
  ClipsFactFactory::register_type("WAIT",
                                  [] { return std::make_unique<WaitFact>(); });
  return true;
}();

} // namespace
