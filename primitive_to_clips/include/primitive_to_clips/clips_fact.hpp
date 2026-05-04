#pragma once

#include <map>
#include <nlohmann/json.hpp>
#include <string>
#include <utility>
#include <vector>

using Slot = std::pair<std::string, std::string>;

/**
 * @brief Abstract base class for CLIPS fact builders.
 *
 * Implements the Factory Method pattern:
 * each subclass knows how to build the CLIPS assert_string
 * for one specific CD primitive type.
 */
class ClipsFact {
public:
  virtual ~ClipsFact() = default;

  /**
   * @brief Build the CLIPS assert_string for this primitive.
   *
   * @param step      1‑based step number in the execution plan.
   * @param primitive CD primitive JSON object from the semantic parser.
   * @return A string ready to be passed to env.assert_string() in CLIPS.
   */
  std::string build(int step, const nlohmann::json &primitive);

protected:
  /**
   * @brief Extract and normalise the relevant slots for this primitive type.
   *
   * Each subclass overrides this to pull only the fields it needs
   * and convert them to CLIPS symbols.
   *
   * @param primitive The CD primitive JSON.
   * @return Map with the relevant slots for this primitive.
   * Only includes fields that should appear in the CLIPS fact.
   */
  virtual std::vector<Slot> extract_slots(const nlohmann::json &primitive) = 0;

private:
  /**
   * @brief Format the final CLIPS assert_string from step number and slot map.
   */
  std::string format_fact(int step, const std::vector<Slot> &slots);

  /**
   * @brief Convert any value to a valid CLIPS symbol.
   *
   * Replaces spaces with underscores, lowercases the result.
   * None / "unknown" → "unknown".
   */
  std::string sym(const nlohmann::json &value);

  /**
   * @brief Normalise entities for physical/world references.
   *
   * Removes determiners "a", "an", "the" after symbol normalisation.
   */
  std::string entity(const nlohmann::json &value);

  /**
   * @brief Extract the common slots shared by all primitive types.
   *
   * Subclasses call this and then override only the specific slots.
   */
  std::vector<Slot> base_slots(const nlohmann::json &primitive);
};
