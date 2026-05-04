#include "primitive_to_clips/clips_facts.hpp"

// ─────────────────────────────────────────────
// PTRANS
// ─────────────────────────────────────────────

std::vector<Slot> PtransFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));
  slots.emplace_back("destination", get_entity(p, "destination"));
  slots.emplace_back("source", get_entity(p, "source"));

  return slots;
}

// ─────────────────────────────────────────────
// ACCOMPANY
// ─────────────────────────────────────────────

std::vector<Slot> AccompanyFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));

  if (p.contains("person")) {
    flatten_object(p["person"], "person", slots);
  }

  slots.emplace_back("source", get_entity(p, "source"));
  slots.emplace_back("destination", get_entity(p, "destination"));

  return slots;
}

// ─────────────────────────────────────────────
// GRASP
// ─────────────────────────────────────────────

std::vector<Slot> GraspFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));
  slots.emplace_back("object", get_entity(p, "object"));
  slots.emplace_back("object_category", get_sym(p, "object_category"));
  slots.emplace_back("location", get_entity(p, "location"));

  return slots;
}

// ─────────────────────────────────────────────
// ATRANS
// ─────────────────────────────────────────────

std::vector<Slot> AtransFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));
  slots.emplace_back("object", get_entity(p, "object"));
  slots.emplace_back("object_category", get_sym(p, "object_category"));
  slots.emplace_back("source", get_entity(p, "source"));
  slots.emplace_back("destination", get_entity(p, "destination"));

  if (p.contains("recipient_person") && p["recipient_person"].is_object()) {

    flatten_object(p["recipient_person"], "recipient_person", slots);
  }

  if (p.contains("recipient_location")) {
    slots.emplace_back("recipient_location",
                       get_entity(p, "recipient_location"));
  }

  return slots;
}

// ─────────────────────────────────────────────
// ATTEND
// ─────────────────────────────────────────────

std::vector<Slot> AttendFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));
  slots.emplace_back("object", get_entity(p, "object"));
  slots.emplace_back("object_category", get_sym(p, "object_category"));
  slots.emplace_back("location", get_entity(p, "location"));

  if (p.contains("person") && p["person"].is_object()) {
    flatten_object(p["person"], "person", slots);
  }

  if (p.contains("query_attribute")) {
    slots.emplace_back("query_attribute", get_sym(p, "query_attribute"));
  }

  if (p.contains("query_filter")) {
    slots.emplace_back("query_filter", get_sym(p, "query_filter"));
  }

  return slots;
}

// ─────────────────────────────────────────────
// QUERY
// ─────────────────────────────────────────────

std::vector<Slot> QueryFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("query_type", get_sym(p, "query_type"));
  slots.emplace_back("target", get_sym(p, "target"));
  slots.emplace_back("target_category", get_sym(p, "target_category"));
  slots.emplace_back("qualifier", get_sym(p, "qualifier"));
  slots.emplace_back("query_attribute", get_sym(p, "query_attribute"));
  slots.emplace_back("location", get_entity(p, "location"));

  return slots;
}

// ─────────────────────────────────────────────
// MTRANS
// ─────────────────────────────────────────────

std::vector<Slot> MtransFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("content", get_sym(p, "content"));
  slots.emplace_back("recipient", get_sym(p, "recipient"));

  if (p.contains("recipient_person") && p["recipient_person"].is_object()) {

    flatten_object(p["recipient_person"], "recipient_person", slots);
  }

  if (p.contains("recipient_location")) {
    slots.emplace_back("recipient_location",
                       get_entity(p, "recipient_location"));
  }

  return slots;
}

// ─────────────────────────────────────────────
// SPEAK
// ─────────────────────────────────────────────

std::vector<Slot> SpeakFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));
  slots.emplace_back("content", get_sym(p, "content"));
  slots.emplace_back("recipient", get_sym(p, "recipient"));

  return slots;
}

// ─────────────────────────────────────────────
// SOCIAL
// ─────────────────────────────────────────────

std::vector<Slot> SocialFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("subtype", get_sym(p, "subtype"));

  if (p.contains("person") && p["person"].is_object()) {
    flatten_object(p["person"], "person", slots);
  }

  slots.emplace_back("location", get_entity(p, "location"));

  return slots;
}

// ─────────────────────────────────────────────
// WAIT
// ─────────────────────────────────────────────

std::vector<Slot> WaitFact::extract_slots(const nlohmann::json &p) {

  auto slots = base_slots(p);

  slots.emplace_back("condition", get_sym(p, "condition"));

  return slots;
}
