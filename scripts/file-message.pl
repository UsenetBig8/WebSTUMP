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
use strict;
use warnings;

# This script reads a message from stdin, figures out which newsgroup's
# queue it should be saved to, and saves it.
#
#
# Figure out the home directory
# Do this in a BEGIN so that the script directory can be added to @INC
# so that 'use' works in a convenient way.
BEGIN {
  our ($webstump_home) = $0 =~ m{^(.*)/scripts/file-message\.pl$};
  if ( !$webstump_home ) {
    # In a BEGIN 'die' causes compilation failure so exit instead.
    print STDERR "This script can only be called with full path name!!!";
    exit(1);
  }
  push @INC, "$webstump_home/scripts";
}
umask 022;
our $webstump_home;

require "$webstump_home/config/webstump.cfg";
require "webstump.lib.pl";
require "filter.lib.pl";

&init_webstump;

my $time      = time;
my $dir       = "dir_${time}_$$";
my $directory = "$webstump_home/tmp/$dir";
mkdir( $directory, 0775 );

my $message;
our $use_mime;
if( $use_mime eq "yes" ) {
  require Webstump::MIME;
  $message = Webstump::MIME::parseMessage($directory);
} else { # no MIME
  require "mime-parsing.lib";
  my $newsgroup;
  my $Subject;
  our ($Article_From,$Article_Subject,$Article_Head,$Article_Body);
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

  while( defined($_ = <STDIN>) && !($_ =~ /^\@+$/ )) {};

  while( defined($_ = <STDIN>) && ($_ =~ /^$/ )) {};
  my $prolog = &decode_plaintext_message( $directory );
  $message = {
    newsgroup => $newsgroup,
    prolog => $Subject . "\n" . $prolog,
    Subject => $Subject,
    Article_From => $Article_From,
    Article_Subject => $Article_Subject,
    Article_Head => $Article_Head,
    Article_Body => $Article_Body
  }
}

my $newsgroup = $message->{newsgroup};

open( my $prologFH, ">:encoding(UTF-8)", "$directory/stump-prolog.txt" )
  || die "open $directory/stump-prolog.txt $!";
print $prologFH $message->{prolog};
close($prologFH);

my $queue_dir = &getQueueDir($newsgroup)
	|| die "Newsgroup $newsgroup is not listed in the newsgroups database";

mkdir $queue_dir, 0755; # it is OK if this fails
chmod 0755, $queue_dir;

die "$queue_dir does not exist or is not writable"
	if( ! -d $queue_dir || ! -w $queue_dir );

rename $directory, "$queue_dir/$dir";

our %request;
$request{"newsgroup"} = $newsgroup;

&review_incoming_message( $message, $dir );
