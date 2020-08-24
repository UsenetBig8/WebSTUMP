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
# This script reads a message from stdin, figures out which newsgroup's
# queue it should be saved to, and saves it.
#
#
# Figure out the home directory
#

umask 022;

if( !($0 =~ /\/scripts\/file-message\.pl$/) ) {
  die "This script can only be called with full path name!!!";
}

$webstump_home = $0;
$webstump_home =~ s/\/scripts\/file-message\.pl$//;

require "$webstump_home/config/webstump.cfg";
require "$webstump_home/scripts/webstump.lib.pl";
require "$webstump_home/scripts/filter.lib.pl";
require "$webstump_home/scripts/mime-parsing.lib";

&init_webstump;

$time = time;
$directory = "$webstump_home/tmp/dir_$time" . "_$$";

$Subject = "";

while( <STDIN> )
{
  chop;
  if( /^X-Moderate-For: / ) {
    s/^X-Moderate-For: //;
    $newsgroup = $_;
  } elsif ( /^Subject: / ) {
    $Subject = $_;
  } elsif ( /^$/ ) {
    last;
  }
}

die
"This message did not look like it came from STUMP because it did not
contain the X-Moderate-For: header"
	if( !$newsgroup );

while( ($_ = <STDIN>) && !($_ =~ /^\@+$/ )) {};

#
# this will also take away the "From " line.
#
while( ($_ = <STDIN>) && ($_ =~ /^$/ )) {};

my ($entity, $prolog);

if( $use_mime eq "yes" ) {
  ($entity, $prolog) = &decode_mime_message( $directory );
} else { # no MIME
  $prolog = &decode_plaintext_message( $directory );
}

$prolog = $Subject . "\n" . $prolog;

die "This message did not look like it came from STUMP because it did not
    contain the X-Moderate-For: header"
	if( !$newsgroup );

$queue_dir = &getQueueDir( $newsgroup ) 
	|| die "Newsgroup $newsgroup is not listed in the newsgroups database";

mkdir $queue_dir, 0755; # it is OK if this fails
chmod 0755, $queue_dir;

die "$queue_dir does not exist or is not writable"
	if( ! -d $queue_dir || ! -w $queue_dir );

open( PROLOG, ">$directory/stump-prolog.txt" );
print PROLOG $prolog;
close( PROLOG );

#open( FULL, ">$directory/full_message.txt" );
#print FULL $entity->as_string;
#close( FULL );

my $dir = "dir_$time" . "_$$";
rename $directory, "$queue_dir/$dir";

&init_webstump;
$request{"newsgroup"} = $newsgroup;

#sub review_incoming_message { # Newsgroup, From, Subject, Message, Dir

&review_incoming_message( $newsgroup, $Article_From, $Subject, 
                          $Article_Subject, $Article_Head . $Article_Body, $dir );
