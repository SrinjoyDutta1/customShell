/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */
%x src
%{

#include <cstring>
#include "y.tab.hh"
#include "shell.hh"




////////////  Start added code ///////////


extern "C" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

/////////// End added code ///////////





static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%


\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">>" {
  return GREATGREAT; 
}
">&" {
  return GREATERAMP;
}
"2>" {
  return TWOGREAT; 
}
">" {
  return GREAT;
}
"<" {
  return LESS;
}
">>&" {
  return GREATGREATAMPERSAND;
}
"|" {
  return PIPE;
}
"&" {
  return AMPERSAND;
}
source {
  BEGIN(src);
}

<src>[ \t]* ;
<src>[^ \t\n]+ {
  yyin = fopen( yytext, "r" );

  if ( ! yyin )
    perror("source");

  yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE ));

  BEGIN(INITIAL);
}

\$\([^\n]*\) {
  std::string mystr = std::string(yytext);

  //remove dollar sign and parentheses
  mystr = mystr.substr(2, mystr.size() - 3);
  //printf("index: %d\n", pindex);
  //printf("This is the string: %s\n", finalstr.c_str());
  mystr += "\nexit\n";

  //create pipe
  int in = dup(0);
  int out = dup(1);
  int pipein[2];
  int pipeout[2];
  pipe(pipein);
  pipe(pipeout);

  dup2(pipein[0], 0);
  close(pipein[0]);

  dup2(pipeout[1], 1);
  close(pipeout[1]);

  //write to pipe
  write(pipein[1], mystr.c_str(), mystr.size());
  close(pipein[1]);

  //create new process and check process value
  int process = fork();
  if (process < 0) {
    perror("fork");
    exit(1);
  }
  //execute the subcommand
  else if (process == 0) {
    char* arg[2];
    arg[0] = (char*) "/proc/self/exe";
    arg[1] = NULL;
    execvp(arg[0], arg);
    perror("subshell");
    exit(1);
  }
  else {
    waitpid(process, NULL, 0);

    dup2(in, 0);
    close(in);

    dup2(out, 1);
    close(out);

    char* space = new char[4096];
    int r = read(pipeout[0], space, 4096);
    close(pipeout[0]);

    //printf("read value: %d\n", r);

    //for (int j = r ; j >= r - 12 ; j--) {
      //printf("%c ", space[j]);
    //}
    //printf("\n");

    //get rid of exit output (Good bye!!)
    for (int i = r - 12 ; i >= 0 ; i--) {
      if (space[i] == '\n')
        space[i] = '\t';

      myunputc(space[i]);
    }
    delete space;
  }
}
[\ ].*\$\{\$\}.* {
  int spid = getpid();
  std::string argument = std::to_string(spid);
  yylval.cpp_string = new std::string(argument);
  return WORD;
}

["][^\n\"]*["] {
  //anything in between quotes that isnt a new line character
  yylval.cpp_string = new std::string(yytext);
  *yylval.cpp_string = yylval.cpp_string->substr(1, yylval.cpp_string->length()-2);

  return WORD;
}



([^ \t\n>|]*)|\\+ {
  //all characters that aren't tabs, newline, and the special characters
  yylval.cpp_string = new std::string(yytext);

  //iterate through string and remove escape character
  for (int i = 0 ; i < yylval.cpp_string->size() ; i++) {
    if (yylval.cpp_string->at(i) == '\\') {
      yylval.cpp_string->erase(i, 1);
    }
  }
  return WORD;
}



<<EOF>> {
  yypop_buffer_state();

  if ( !YY_CURRENT_BUFFER )
  {
    yyterminate();
  }
}

