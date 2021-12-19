#
# Copyright 1999 Igor Chudov
# Copyright 2021 Owen Rees
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
package Webstump::ListAdmin;

# Functions for managing moderation related options

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(
  listsInOrder getListLabel
  getRejectionMessage
  getRejectionReasons deleteRejectionReason updateRejectionReason
  decisionForSTUMP
);

my $configLists = {
  "good.posters.list"   => { seq => 1, label => "Good Posters List" },
  "watch.posters.list"  => { seq => 2, label => "Suspicious Posters List" },
  "bad.posters.list"    => { seq => 3, label => "Banned Posters List" },
  "good.subjects.list"  => { seq => 4, label => "Good Subjects List" },
  "watch.subjects.list" => { seq => 5, label => "Suspicious Subjects List" },
  "bad.subjects.list"   => { seq => 6, label => "Banned Subjects List" },
  "watch.words.list"    => { seq => 7, label => "Suspicious Words List" },
  "bad.words.list"      => { seq => 8, label => "Banned Words List" }

};

sub listsInOrder {
  return sort { $configLists->{$a}->{seq} <=> $configLists->{$b}->{seq} } keys(%$configLists);
}

sub getListLabel {
  my ($list) = @_;
  my $entry = $configLists->{$list} // {};
  return $entry->{label} // q{};
}
my $rejection_reasons = {};

sub getRejectionReasons {
  my ($newsgroup) = @_;
  if ( scalar( keys(%$rejection_reasons) == 0 ) ) {
    my $reasons = main::full_config_file_name("rejection-reasons");
    open( my $fh, '<', $reasons ) || main::error("Could not open file $reasons");
    while ( my $line = <$fh> ) {
      chomp $line;
      if ( my ( $name, $title ) = $line =~ m{\A(\w+)::(.*)\z} ) {
        $rejection_reasons->{$name} = $title;
      }
    }
    close $fh;
  }
  return $rejection_reasons;
}

sub deleteRejectionReason {
  my ( $newsgroup, $deleteReason ) = @_;
  my $reasons = getRejectionReasons($newsgroup);
  delete $reasons->{$deleteReason};

  my $file = rejectionMessageFileName($deleteReason);
  unlink($file);
  saveRejectionReasons($newsgroup);
}

sub updateRejectionReason {
  my ( $newsgroup, $reason, $request ) = @_;
  my $reasons = getRejectionReasons($newsgroup);
  $reasons->{$reason} = $request->{description};
  saveRejectionMessage( $reason, $request->{message} );
  saveRejectionReasons($newsgroup);
}

sub saveRejectionReasons {
  my ($newsgroup) = @_;
  my $reasons = getRejectionReasons($newsgroup);
  my $reasonsFile = main::full_config_file_name("rejection-reasons");
  open( my $fh, '>', $reasonsFile ) || main::error("Could not write file $reasons");
  foreach my $reason ( sort( keys(%$reasons) ) ) {
    printf $fh "%s::%s\n", $reason, $reasons->{$reason};
  }
  close $fh;
}

sub getRejectionMessage {
  my ($reason) = @_;
  my $file = rejectionMessageFileName($reason);
  if ( -r $file ) {
    open( my $fh, '<', $file ) || main::error("open < $file $!");

    # Set record separator $/ locally to undef so that <$fh> reads
    # the whole file
    my $message = do { local $/; <$fh> };
    close $fh;
    return $message;
  }
  return q{};
}

# Wrap long lines at column 72
# This uses forward lookahead to find lines of 73 characters or more.
# If there is whitespace within the first 72 characters, the last
# sequence of whitespace in the 72 characters will be replaced by a newline
# and the substitution will repeat as many times as needed. If there is no
# whitespace in the first 72 characters, the first whitespace sequence after
# 72 characters will be replaced by a newline.
sub wrapAt72 {
  my ($text) = @_;
  # Add a newline at the end if not there already
  $text =~ s/([^\n])\z/$1\n/;
  $text =~ s/(?=.{73,})(.{0,72})\s+/$1\n/mg;
  return $text;
}

sub saveRejectionMessage {
  my ( $reason, $message ) = @_;
  my $file = rejectionMessageFileName($reason, 1);
  open( my $fh, '>', $file ) || main::error("open > $file $!");
  print $fh $message;
  close $fh;
}

sub rejectionMessageFileName {
  my ( $reason, $createDir ) = @_;
  my $dir = main::full_config_file_name("messages");
  if ( $createDir && !-d $dir ) {
    mkdir($dir) || main::error("mkdir($dir) $!");
  }
  return main::full_config_file_name("messages/reject-$reason.txt");
}

# Use Webstump managed message if there is one
# Note that both the rejection message and the comment are wrapped
# here rather than depending on STUMP to do that so that this is ready for
# rejection messages to be sent directly by Webstump.
sub decisionForSTUMP {
  my ($decision, $comment) = @_;
  if ($comment) {$comment = wrapAt72($comment)}
  if (my ($r, $reason, $rest) = $decision =~ m{\A(reject\s+)(\w+)(.*)\z}) {
    if (my $message = getRejectionMessage($reason)) {
      $decision = "${r}custom${rest}";
      $comment = ($comment ? "$comment\n" : q{}) . wrapAt72($message);
    }
  }
  return "\n$decision\n" . ($comment ? "comment $comment" : q{});
}

1;
