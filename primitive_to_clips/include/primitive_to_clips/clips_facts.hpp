#pragma once

#include "primitive_to_clips/clips_fact.hpp"

class PtransFact : ClipsFact {
protected:
  std::vector<Slot> extract_slots(const nlohmann::json &primivite) override;
};
