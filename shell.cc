#include <cstdio>

#include "shell.hh"
#include <bits/stdc++.h>

int yyparse(void);
void yyrestart(FILE * file);
bool Shell::_prom = false;




void Shell::prompt() {
  //check prom variable is true or false
  if (isatty(0) && _prom) {
    printf("myshell>");
    fflush(stdout);
  }

  fflush(stdout);
}

extern "C" void cc(int number) {
  printf("\n");
  Shell::prompt();
}

extern "C" void zombieElim(int num) {
  pid_t pid;
  std::vector<pid_t>::iterator i;

  //get rid of pid if it contains the pid
  while ((pid = waitpid(-1, NULL, WNOHANG)) > 0) {
    i = std::find(Shell::_PIDarr.begin(), Shell::_PIDarr.end(), pid);
    if (i != Shell::_PIDarr.end()) {
      //prints
      printf("[%d] exited.\n", pid);
      Shell::_PIDarr.erase(i);
    }
  }
}
int main() {
  //Control C handling
  struct sigaction ctrlc;
  ctrlc.sa_handler = cc;
  sigemptyset(&ctrlc.sa_mask);
  ctrlc.sa_flags = SA_RESTART;

  if (sigaction(SIGINT, &ctrlc, NULL)) {
    perror("sigaction");
    exit(2);
  }
  //This is for zombie elimination 
  //Zombie Elim
  struct sigaction sigact;
  sigact.sa_handler = zombieElim;
  sigemptyset(&sigact.sa_mask);
  sigact.sa_flags = SA_RESTART;


  if (sigaction(SIGCHLD, &sigact, NULL)) {
    perror("sigaction");
    exit(2);
  }

  //opens file shellrc
  Shell::_prom = false;
  FILE* f = fopen(".shellrc", "r");
  if (f) {
    yyrestart(f);
    yyparse();
    yyrestart(stdin);
    fclose(f);
  }
  Shell::_prom = true;
  Shell::prompt();
  yyparse();


}


Command Shell::_currentCommand;
std::vector<int> Shell::_PIDarr;

