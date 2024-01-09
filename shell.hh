#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static void prompt();
  static bool _prom;
  static std::vector<int> _PIDarr;
  static Command _currentCommand;
};

#endif
