#include <cstdio>
#include <cstdlib>

#include <iostream>

#include "command.hh"
#include "shell.hh"


Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _append = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if (_outFile && _outFile == _errFile) {
      delete _outFile;
      _errFile = NULL;
      _outFile = NULL;

    }
    else {
      if ( _errFile ) {
        delete _errFile;
      }
      _errFile = NULL;

      if ( _outFile ) {
        delete _outFile;
      }
      _outFile = NULL;
    }
    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;



    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
    _append = 0;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }

    // Print contents of Command data structure
    //print();

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec
    //This is the part 1 stuff
    int p;
    int defIPT = dup(0);
    int defOPT = dup(1);
    int defERR = dup(2);
    int first = 0;
    int second = 0;
    int third = 0;

    if (_errFile) {
      if (_append) {
        third = open(_errFile->c_str(), O_WRONLY | O_APPEND | O_CREAT, 0600);
      }
      else {
        third = open(_errFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
      }
    }
    else {
      third = dup(defERR);
    }
    dup2(third, 2);
    close(third);


    if (_inFile) {
      first = open(_inFile->c_str(), O_RDONLY);
    }
    else {
      first = dup(defIPT);
    }




    for (int i = 0 ; i < _simpleCommands.size() ; i++) {
//environment var

        //This will be checking if command name is setenv
    if (strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "setenv") == 0) {
      if (setenv(_simpleCommands[i]->_arguments[1]->c_str(), _simpleCommands[i]->_arguments[2]->c_str(), 1)) {
        perror("setenv");
      }
      clear();
      Shell::prompt();
      return;
    }



      //This will be checking if command name is unsetenv
    if( strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "unsetenv") == 0 ) {
      if (unsetenv(_simpleCommands[i]->_arguments[1]->c_str())) {
        perror("unsetenv");
      }
      clear();
      Shell::prompt();
      return;
    }


      int status;
  //This checks if command name is cd
    if (strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "cd") == 0) {
      //this is to go to the home directory
      if (_simpleCommands[i]->_arguments.size() == 1) {
        status = chdir(getenv("HOME"));
      }
      else {
        status = chdir(_simpleCommands[i]->_arguments[1]->c_str());
      }

      if (status < 0) {
        //perror("cd");
        fprintf(stderr, "cd: can't cd to %s\n", _simpleCommands[i]->_arguments[1]->c_str());
      }

      clear();
      Shell::prompt();
      return;
    }
      dup2(first, 0);
      close(first);


     if (i < _simpleCommands.size() - 1) {
        int fdpipe[2];
        pipe(fdpipe);
        first = fdpipe[0];
        second = fdpipe[1];
     } else {
        if (_outFile && _append) {
            second = open(_outFile->c_str(), O_WRONLY | O_APPEND | O_CREAT, 0600);
         }
          else if (_outFile && !_append){
            second = open(_outFile->c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);
        } else {
          second = dup(defOPT);
        }
      }

      dup2(second, 1);
      close(second);

      p = fork();
//environment var



      if (p == 0) {

    //This if statement is to check if command name is printenv
    if (strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv") == 0) {
      char** en = environ;

      // This loop will print all the environmental variables
      while (*en != NULL) {
        printf("%s\n", *en);
        en++;
      }
      exit(1);
    }
    
    
        // This is to execute the command
        char** args = new char* [_simpleCommands[i]->_arguments.size() + 1];

        for (int j = 0 ; j < _simpleCommands[i]->_arguments.size() ; j++) {
          args[j] = const_cast<char*> (_simpleCommands[i]->_arguments[j]->c_str());
        }
        args[_simpleCommands[i]->_arguments.size()] = NULL;
        execvp(args[0], args);
      }
    }
    dup2(defIPT, 0);
    close(defIPT);

    dup2(defOPT, 1);
    close(defOPT);

    dup2(defERR, 2);
    close(defERR);

    if (!_background) {
    int status;
      waitpid(p, &status, 0);
      //environment vars
      setenv("?", std::to_string(WEXITSTATUS(status)).c_str(), 1);

    } else {
      // addng the pid
      //evnironment vars
     setenv("!", std::to_string(p).c_str(), 1);

      Shell::_PIDarr.push_back(p);
    }
    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}

SimpleCommand * Command::_currentSimpleCommand;
