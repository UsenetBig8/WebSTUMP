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
#

if( !($0 =~ /\/scripts\/webstump\.pl$/) ) {
  die "This script can only be called with full path name!!!";
}

$webstump_home = $0;
$webstump_home =~ s/\/scripts\/webstump\.pl$//;

$webstump_home =~ /(^.*$)/;
$webstump_home = $1;

require "$webstump_home/config/webstump.cfg";
require "$webstump_home/scripts/webstump.lib.pl";
require "$webstump_home/scripts/filter.lib.pl";
require "$webstump_home/scripts/html_output.pl";

$html_mode = "yes";

&init_webstump;

######################################################################

%request = &readWebRequest;

$command = "";

if( %request ) {
  &disinfect_request;
  $command = $request{'action'} if( defined $request{'action'} );
}

if( ! $command ) {
  &html_welcome_page;
} else {
  &processWebRequest( $command );
}
