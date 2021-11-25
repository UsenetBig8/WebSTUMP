/*
   Copyright 1999 Igor Chudov

   This file is part of WebSTUMP.

   WebSTUMP is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   WebSTUMP is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with WebSTUMP.  If not, see <https://www.gnu.org/licenses/>.
*/

/*
 * WebSTUMP wrapper. You have to compile this program using "make" and
 * make sure that it is installed under ../bin. It should be set up as 
 * setuid your user id. Directory referred to by webstump_home should
 * exist and belong to the effective user id or the program will refuse
 * to run.
 */


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

const char * webstump_home = WEBSTUMP_HOME;

const char * script_name = "scripts/webstump.pl";

#define SCRIPT_FILE_NAME_MAX 1024
#define MESSAGE_MAX 100

const char *safe_env[] = {
	"SERVER_SOFTWARE",
	"SERVER_NAME",
	"GATEWAY_INTERFACE",
	"SERVER_PROTOCOL",
	"SERVER_PORT",
	"REQUEST_METHOD",
	"HTTP_ACCEPT",
	"PATH_INFO",
	"PATH_TRANSLATED",
	"SCRIPT_NAME",
	"QUERY_STRING",
	"REMOTE_HOST",
	"REMOTE_ADDR",
	"REMOTE_USER",
	"AUTH_TYPE",
	"CONTENT_TYPE",
	"CONTENT_LENGTH",
	NULL
};

void cgi_error( const char * buf );

/* Wrapper code. Argc and argv are ignored, except fot the list of 
 * predefined variables.
 */

int main( int argc, char * argv[] ) /* argv is ignored */
{
  char * new_env[ 1000 ];       /* new environment */
  char * new_argv[] = { NULL }; /* no arguments    */
  char script_file_name[ SCRIPT_FILE_NAME_MAX ];
  char buf[ SCRIPT_FILE_NAME_MAX+MESSAGE_MAX ];
  int i, new_env_i;
  struct stat stat_buf;

  for( i = 0, new_env_i = 0; safe_env[i] != NULL; i++ )
  {
    char * var;
    if( (var = getenv( safe_env[i] )) != NULL ) {
      char * new_var = malloc( strlen( safe_env[i] ) + 1 + strlen( var ) + 1 );
      if( new_var != NULL )
	{
	  strcpy( new_var, safe_env[i] );
	  strcat( new_var, "=" );
	  strcat( new_var, var );
      	  new_env[ new_env_i++ ] = new_var;
	}
    }
  }

  new_env[new_env_i] = NULL;

  /* check existence and ownership of the perl script */
  if (strlen(webstump_home) + 1 + strlen(script_name) + 1 > SCRIPT_FILE_NAME_MAX) {
      cgi_error( "Script name too long for buffer" );
      exit( 0 );
  }
  strcpy( script_file_name, webstump_home );
  strcat( script_file_name, "/" );
  strcat( script_file_name, script_name );

  if( stat( script_file_name, & stat_buf ) != 0 )
    {
      sprintf( buf, "Could not access file %s to check permissions.",
               script_file_name );
      cgi_error( buf );
      exit( 0 );
    }

  if( stat_buf.st_uid != geteuid() )
    {
      sprintf( buf, "Security violation: file %s \n"
                    "belongs to a different user than my effective user id.",
               script_file_name );
      cgi_error( buf );
      exit( 0 );
    }

  if( stat_buf.st_mode & (020 | 02) ) /* group or world writable */
    {
printf( "File mode = %o, compared to %o\n", stat_buf.st_mode, (020 | 02) );
      sprintf( buf, "Security violation: file %s \n"
                    "is group or world writable.",
               script_file_name );
      cgi_error( buf );
      exit( 0 );
    }

  execve( script_file_name, new_argv, new_env );

  /* We can only be here if it could not be executed */

  sprintf( buf, "Error: could not execute file %s", script_file_name );
  cgi_error( buf );
}


void cgi_error( const char * buf )
{
  printf( 
"Content-Type: text/html\n\n"
"<TITLE>WebSTUMP Error</TITLE>\n"
"<H1>WebSTUMP Error</H1>\n"
"%s\n\n", 
	buf );
}
