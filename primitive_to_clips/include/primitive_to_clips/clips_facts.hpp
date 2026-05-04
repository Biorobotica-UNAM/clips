#pragma once

#include "primitive_to_clips/clips_fact.hpp"

// ─────────────────────────────────────────────
// Movement primitives
// ─────────────────────────────────────────────

class PtransFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

class AccompanyFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

// ─────────────────────────────────────────────
// Object manipulation
// ─────────────────────────────────────────────

class GraspFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

class AtransFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

// ─────────────────────────────────────────────
// Perception / reasoning
// ─────────────────────────────────────────────

class AttendFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

class QueryFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

// ─────────────────────────────────────────────
// Communication
// ─────────────────────────────────────────────

class MtransFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

class SpeakFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

// ─────────────────────────────────────────────
// Social interaction
// ─────────────────────────────────────────────

class SocialFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};

// ─────────────────────────────────────────────
// Wait
// ─────────────────────────────────────────────

class WaitFact : public ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primitive) override;
};
