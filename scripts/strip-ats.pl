#!/usr/local/bin/perl

$after_ats = 0;

while( <STDIN> ) {

  if( $after_ats ) {
	print;
  } elsif( /^\@\@\@/ ) {
        $after_ats = 1;
  }
}
