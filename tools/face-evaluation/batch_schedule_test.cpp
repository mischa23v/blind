#include "../../ios/BlindAssist/FamiliarNative/BAFaceBatchSchedule.hpp"
#include <cassert>
#include <set>
#include <limits>

int main() {
    assert(ba_face::slots(0, 0).empty());
    assert(ba_face::slots(-1, 0).empty());
    assert(ba_face::slots(33, 0).empty());
    assert(ba_face::slots(1, 9) == std::vector<int>{0});
    assert((ba_face::slots(3, -2) == std::vector<int>{0, 1}));
    assert((ba_face::slots(3, 2) == std::vector<int>{2, 0}));
    for (int count = 1; count <= 32; ++count) {
        int cursor = 0;
        std::set<int> seen;
        for (int pass = 0; pass < count; ++pass) {
            const auto slots = ba_face::slots(count, cursor);
            assert(slots.size() <= 2);
            assert(std::set<int>(slots.begin(), slots.end()).size() == slots.size());
            for (int slot : slots) { assert(slot >= 0 && slot < count); seen.insert(slot); }
            cursor = (slots.back() + 1) % count;
        }
        assert(seen.size() == static_cast<size_t>(count));
        for (int slot : ba_face::slots(count, std::numeric_limits<long>::max())) assert(slot >= 0 && slot < count);
    }
}
