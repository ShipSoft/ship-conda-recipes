#include "phlex/core/product_selector.hpp"
#include "phlex/module.hpp"

using namespace phlex;

namespace {
  int twice(int i) { return 2 * i; }
}

PHLEX_REGISTER_ALGORITHMS(m, config)
{
  m.transform("twice", twice, concurrency::unlimited)
    .input_family(product_selector{.creator = "input", .layer = "event", .suffix = "i"})
    .output_product_suffixes(config.get<std::string>("produces", "doubled"));
}
