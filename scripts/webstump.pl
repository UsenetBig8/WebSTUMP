#!/usr/bin/env perl
#
# Copyright 1999 Igor Chudov
#
# This file is part of WebSTUMP.
# 
# WebSTUMP is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# WebSTUMP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with WebSTUMP.  If not, see <https://www.gnu.org/licenses/>.
#
# This is the main webstump cgi script.
#
# Figure out the home directory
# Do this in a BEGIN so that the script directory can be added to @INC
# so that 'use' works in a convenient way.
use strict;
use warnings;

# declare global variables
# TODO eliminate global variables
our $html_mode;
our %request;
our $webstump_home;

BEGIN {
  ($webstump_home) = $0 =~ m{^(.*)/scripts/webstump\.pl$};
  if ( !$webstump_home ) {
    # In a BEGIN 'die' causes compilation failure so exit instead.
    print STDERR "This script can only be called with full path name!!!";
    exit(1);
  }
  push @INC, "$webstump_home/scripts";
}


require "$webstump_home/config/webstump.cfg";
require "webstump.lib.pl";
require "filter.lib.pl";
require "html_output.pl";

$html_mode = "yes";

&init_webstump;

######################################################################

%request = &readWebRequest;

my $command = "";

if( %request ) {
  &disinfect_request;
  $command = $request{'action'} if( defined $request{'action'} );
}

if( ! $command ) {
  &html_welcome_page;
} else {
  &processWebRequest( $command );
}
