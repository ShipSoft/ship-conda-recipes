#include <mp-units/systems/si.h>

int main()
{
  using namespace mp_units::si::unit_symbols;
  constexpr auto d = 120 * km;
  constexpr auto t = 2 * h;
  static_assert(d / t == 60 * km / h);
  return 0;
}
