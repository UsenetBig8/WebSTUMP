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
package Webstump::MIME;

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(
  parseMessage
);

use MIME::Parser;
use Convert::UU qw{uudecode};

sub parseMessage {
  my ($directory) = @_;

  my $parser = new MIME::Parser;
  my $outer  = $parser->parse( \*STDIN )
    or die "couldn't parse incoming message";

  my $body    = $outer->bodyhandle;
  my $Subject = $outer->head->get('Subject');
  chomp $Subject;
  my $newsgroup = $outer->head->get('X-Moderate-For');
  chomp $newsgroup;

  die "This message did not look like it came from STUMP because it did not
contain the X-Moderate-For: header or had the wrong structure."
    if ( !$newsgroup || !defined($body) );

  # Get the message to moderate out of the body. It is everything that follows
  # a line of '@' characters - check for at least 10 here.
  my $BodyFH = $body->open('r') || die "Failed to open body of parsed message";
  while (<$BodyFH>) {
    last if m[^\@{10,}$];
  }
  my $fullMessage = "$directory/full_message.txt";
  open( my $fullFH, '>', $fullMessage )
    || die "Failed to open $directory/full_message.txt for writing";
  while (<$BodyFH>) {
    print $fullFH $_;
  }
  close $fullFH;
  close $BodyFH;
  $parser->filer->purge;

  # Now parse the message to moderate and create the prolog
  $parser->output_dir($directory);
  my $message = $parser->parse_open($fullMessage)
    || die "Failed to parse embedded message";

  my $Article_From = $message->head->get("From");
  chomp $Article_From;
  my $Article_Subject = $message->head->get("Subject");
  chomp $Article_Subject;
  our $Article_Head = $message->head->as_string;
  my $Article_Body = $message->stringify_body();

  open( my $fileList, ">", "$directory/text.files.lst" )
    || die "open $directory/text.files.lst $!";

  writeStringToFile( "$directory/headers.txt", $Article_Head );

  if ( $message->is_multipart() ) {
    print $fileList doParts( $directory, [ $message->parts() ], "part" );
  } else {
    print $fileList doParts( $directory, [$message], "body" );
  }
  close $fileList;
  return {
    newsgroup => $newsgroup,
    prolog => "Subject: $Subject\nFrom: $Article_From\nReal-Subject: $Article_Subject\n\n",
    Subject => $Subject,
    Article_From => $Article_From,
    Article_Subject => $Article_Subject,
    Article_Head => $Article_Head,
    Article_Body => $Article_Body
  }
}

sub writeStringToFile {
  my ( $file, $string ) = @_;
  open( my $FH, ">:encoding(UTF-8)", "$file" ) || die "open $file $!";
  print $FH $string;
  close($FH);
}

sub doPlainTextPart {
  my ( $directory, $part, $type, $disposition, $fallback ) = @_;
  my $bodytxt = $part->stringify_body();
  if ( my $files = splitUUEncoded( $directory, $bodytxt, $disposition, $fallback ) ) {
    return $files;
  }
  if ( my $body = $part->bodyhandle() ) {
    if ( my $fullpath = $body->path() ) {
      my ( $d, $file, $ext ) =
        $fullpath =~ m{^((?:.*/)?)([^/]+?)((?:\.[^/.]*)?)$};
      return "$file$ext $type $disposition\n";
    }
  }

  # Either no bodyhandle or no path - in either case, save the text as a part
  writeStringToFile( "$directory/${fallback}.txt", $bodytxt );
  return "${fallback}.txt $type $disposition\n";
}

sub doOtherPart {
  my ( $directory, $part, $type, $disposition, $fallback ) = @_;
  if ( my $body = $part->bodyhandle() ) {
    if ( my $fullpath = $body->path() ) {
      my ( $d, $file ) = $fullpath =~ m{^(.*/)?([^/]+)$};
      return "$file $type $disposition\n";
    }
    my ($ext) = $type =~ m{/([^/]+)$};
    my $file = join( '.', $fallback, ( $ext || () ) );
    open( my $FH, ">", "$directory/$file" ) || die "open $directory/$file $!";
    $body->print($FH);
    close $FH;
    return "$file $type $disposition\n";
  } else {
    return doParts( $directory, [ $part->parts() ], $fallback );
  }
}

sub doParts {
  my ( $directory, $parts, $fallback ) = @_;
  my $partNo = 1;
  my $files = "";
  foreach my $part (@$parts) {
    my $type        = $part->effective_type();
    my $disposition = $part->head->mime_attr('content-disposition');
    $disposition ||= 'inline';
    if ( $type =~ m{^text/plain} ) {
      $files .= doPlainTextPart( $directory, $part, $type, $disposition, $fallback );
    } else {
      $files .= doOtherPart( $directory, $part, $type, $disposition, $fallback );
    }
  }
  return $files;
}

# Note that MIME::Parser has a uudecode feature but that throws away
# any text after the first uuencoded piece so do it directly here.
sub splitUUEncoded {
  my ( $directory, $bodytxt, $disposition, $file ) = @_;
  my $count = 0;

  # Capture the files of the split but do not update the list yet
  my $files = "";

  # Throw away pure whitespace parts - loop while there is non-whitespace
  while ( $bodytxt =~ /\S/ ) {
    my ( $data, $name, $mode ) = &uudecode($bodytxt);
    if ( $data && $name ) {

      # Split into prelude text before UUencode, UUencode part, the rest
      my ( $prelude, $postlude ) = $bodytxt =~ /^(.*?\n)begin.*?\nend\n(.*)$/s;
      if ( $prelude =~ /\S/ ) {
        my $partname = sprintf( "%s-%02d.txt", $file, $count++ );
        writeStringToFile( "$directory/$partname", $prelude );
        $files .= "$partname text/plain $disposition\n";
      }

      # Strip any directory from the file name and capture image extension
      $name =~ m{^(?:.*/)?(?<f>[^/]+?(?:\.((?<i>gif|jpe?g|png)|[^/.]+))?)$};
      my $filename = $+{f};
      my $type     = $+{i} ? "image/$+{i}" : "application/uudecoded";
      if ( open( my $FH, ">", "$directory/$filename" ) ) {
        print $FH $data;
        close $FH;
        chmod 0644, "$directory/$filename";
        $files .= "$filename $type $disposition\n";
      } else {

        # If we fail to write one of the files bail out and
        # just show the part as plaintext.
        return "";
      }
      $bodytxt = $postlude;
    } else {

      # No more UUencode found
      last;
    }
  }

  # If we have already captured some files and there is nore non-whitespace
  # capture that too.
  if ( $files && ( $bodytxt =~ /\S/ ) ) {
    my $partname = sprintf( "%s-%02d.txt", $file, $count++ );
    writeStringToFile( "$directory/$partname", $bodytxt );
    $files .= "$partname text/plain $disposition\n";
  }
  return $files;
}

1;
