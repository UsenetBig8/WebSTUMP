#!/usr/local/bin/perl
#
# This script reads a message from stdin, figures out which newsgroup's
# queue it should be saved to, and saves it.
#
#
# Figure out the home directory
#

if( !($0 =~ /\/scripts\/gatekeeper-file-message\.pl$/) ) {
  die "This script can only be called with full path name!!!";
}

$webstump_home = $0;
$webstump_home =~ s/\/scripts\/gatekeeper-file-message\.pl$//;

require "$webstump_home/config/webstump.cfg";
require "$webstump_home/scripts/webstump.lib.pl";

&init_webstump;

$Subject = "";

$newsgroup = @ARGV[0] || die "Syntax: $0 newsgroup.name";

$queue_dir = &getQueueDir( $newsgroup ) 
	|| die "Newsgroup $newsgroup is not listed in the newsgroups database";

mkdir $queue_dir, 0700; # it is OK if this fails

die "$queue_dir does not exist or is not writable"
	if( ! -d $queue_dir || ! -w $queue_dir );

$time = time;
$file = "$queue_dir/$time.$$";
open( QUEUE_FILE, ">$file" ) || die "Could not open $file for writing";

while( <STDIN> ) {
  print QUEUE_FILE;
}

close( QUEUE_FILE );
