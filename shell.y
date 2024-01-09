/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *      cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires
{
#include <string>
#include <string.h>
#include <regex.h>
#include <dirent.h>
#include <algorithm>
#include <sys/types.h>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token GREAT NEWLINE PIPE AMPERSAND LESS GREATERAMP GREATGREAT GREATGREATAMPERSAND NOTHING TWOGREAT

%{
//#define yylex yylex
#define MAXFILENAME 1024
#include <cstdio>
#include "shell.hh"
#include <string>



void yyerror(const char * s);
bool cmp(char* str1, char* str2);
void expandWildcard(char* prefix, char* suffix);
int yylex();
//expandWildcard patters with function
void expandWildcard(char * prefix, char * suffix) {
  //fprintf(stderr, "pre: %s\nsuf: %s\n\n", prefix, suffix);


  if (suffix[0] == 0) {
    Command::_currentSimpleCommand->insertArgument(new std::string(prefix));
    return;
  }

  char firstPref[MAXFILENAME];
  if (prefix[0] == 0) {
    if (suffix[0] == '/') {
      suffix++;
      sprintf(firstPref, "%s/", prefix);
    }
    else {
      strcpy(firstPref, prefix);
    }
  }
  else {
    sprintf(firstPref, "%s/", prefix);
  }
  
  char comp[MAXFILENAME];
  char * slash = strchr(suffix, '/');
  if (slash == NULL) {
    strcpy(comp, suffix);
    suffix = suffix + strlen(suffix);
  } else {
    strncpy(comp, suffix, slash - suffix);
    comp[slash - suffix] = 0;
    suffix = slash + 1;
  }

  char newPrefix[MAXFILENAME];

  if (strchr(comp,'?') == NULL && strchr(comp,'*') == NULL) {
    if (firstPref[0] != 0) {
      sprintf(newPrefix, "%s/%s", prefix, comp);
    } else {
      strcpy(newPrefix, comp);
    }

    expandWildcard(newPrefix, suffix);
    return;
  }
//create regular expression pattern from wildcard pattern
  char * regexpress = (char*)malloc(strlen(comp)*2+10);
  char * r = regexpress;
  *r = '^'; r++;
  int i = 0;
  while (comp[i]) {
    if (comp[i] == '*') {
    *r='.'; 
    r++; 
    *r='*';
    r++;
    } else if (comp[i] == '?') {
    *r='.';
    r++;
    }
    else if (comp[i] == '.') {
    *r='\\'; 
    r++; 
    *r='.'; 
    r++;
    }
    else {*r=comp[i]; 
    r++;
    }
    i++;
  }
  *r='$';
  r++;
  *r=0;
// compile and execute regular expression to match filenames
  regex_t regex;
  int expbuf = regcomp(&regex, regexpress, REG_EXTENDED|REG_NOSUB);

  char* givendirectory;
  if (firstPref[0] == 0) {
    givendirectory = (char*)".";
  }
  else {
    givendirectory = firstPref;
  }
//gets directory
  DIR * new_directory = opendir(givendirectory);
  if (new_directory == NULL) {
    return;
  }

  struct dirent * ent;
  //bool get = false;
  std::vector<char *> thevector = std::vector<char *>();
  while ((ent = readdir(new_directory)) != NULL) {
    if(regexec(&regex, ent->d_name, 1, NULL, 0) == 0) {
      if (firstPref[0] == 0) {
        strcpy(newPrefix, ent->d_name);
      }
      else {
        sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
      }

      if (regexpress[1] == '.') {
        if (ent->d_name[0] != '.') {
          thevector.push_back(strdup(newPrefix));
        }
      }
      else {
          thevector.push_back(strdup(newPrefix));
      }
    }
  }

  std::sort(thevector.begin(), thevector.end(), cmp);

  for (auto iter = thevector.begin(); iter < thevector.end(); iter++) {
    expandWildcard(*iter, suffix);
    free(*iter);
  }

  regfree(&regex);
  closedir(new_directory);
  free(regexpress);
}
%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:
  pipe_list iomodifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE
  | error NEWLINE { yyerrok; }
  ;

pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    //Command::_currentSimpleCommand->insertArgument( $1 );
    //expandWildcardsIfNecessary($1);
    int size = Command::_currentSimpleCommand->_arguments.size();
    expandWildcard("", (char*)$1->c_str());

    if (size == Command::_currentSimpleCommand->_arguments.size()) {
      Command::_currentSimpleCommand->insertArgument($1);
    } else delete $1;

    //expandWildcard("", (char *)$1->c_str());
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    if (strcmp($1->c_str(), "exit") == 0) {
      printf("Good bye!!\n");
      exit(1);
    }
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_list:
  iomodifier_list iomodifier_opt
  | iomodifier_opt
  |
  ;

iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile != NULL) {
      printf("Ambiguous output redirect.\n");
    }
    else{
      Shell::_currentCommand._outFile = $2;
    }
  }
  | GREATGREAT WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._append = 1;
      Shell::_currentCommand._outFile = $2;
  }
  | GREATERAMP WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
  }
  | GREATGREATAMPERSAND WORD {
      //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
      Shell::_currentCommand._append = 1;
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = $2;
  }
  | LESS WORD {
      //printf("   Yacc: insert input \"%s\"\n", $2->c_str());
      Shell::_currentCommand._inFile = $2;
  }
  | TWOGREAT WORD {
      //printf("   Yacc: insert error \"%s\"\n", $2->c_str());
      Shell::_currentCommand._errFile = $2;
  }
  ;

background_opt:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  |
  ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

bool cmp(char* str1, char* str2) {
  return strcmp(str1, str2) < 0;
}



#if 0
main()
{
  yyparse();
}
#endif
