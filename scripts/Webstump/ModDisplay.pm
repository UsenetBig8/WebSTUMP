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
package Webstump::ModDisplay;

# Display functions for moderation pages

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(displayArticle);

use HTML::Escape qw/escape_html/;

sub inline_image {
  my ( $base, $file, $type ) = @_;

  my ($subtype)   = $type =~ m{^image/(gif|jpe?g|png)$};
  my ($extension) = $file =~ m{\.(:?gif|jpe?g|png)$}i;
  if ( $subtype && $extension ) {
    print qq{<img src="$base/$file">};
  } else {
    print qq{<span class="warning">$type $file not shown</span>};
  }
}

# Note that this will be inside a PRE-like DIV so do not put in any
# extra newlines outside the tags.
# TODO add buttons and scripts to switch between summary and full
sub collapsible {
  my ( $notefmt, $lines, $options ) = @_;
  if ( my $nLines = scalar(@$lines) ) {
    my $hide = qq{ style="display:none;"};
    print("<div class=collapsible>");
    printf( qq{<div class="summary"%s>}, $options->{collapsed} ? q{} : $hide );
    printf( $notefmt,                      $nLines );
    print(qq{</div>});
    my $prefix = $options->{prefix};
    printf( qq{<div class="full"%s>}, $options->{collapsed} ? $hide : q{} );
    foreach my $line (@$lines) {
      print escape_html( $prefix->($line) );
    }
    print(qq{</div>});

    print("</div>");
  }
}

sub optForClass {
  my ($class) = @_;
  if ( $class eq 'multi' ) {
    return {
      prefix => sub {
        my ($line) = @_;
        chomp $line;
        # TODO make the prefix configurable via options in a web form
        return substr( q{>>>>>>  } . $line, 0, 75 ) . "\n";
      },
      collapsed => 1
    };
  }
  return {
    prefix => sub {
      return @_;
    },
    collapsed => 0

  };
}

sub displayArticle {
  my ( $url, $newsgroup, $file, $class, $limit ) = @_;
  my ($dir)      = main::getQueueDir($newsgroup) =~ m{^(.+)$};
  my $articleDir = "$dir/$file";
  my $linkbase   = "$url/queues/$newsgroup/$file";
  my $partsList  = "$articleDir/text.files.lst";
  my $lineCount = defined($limit) ? $limit : 1;
  my $inc       = defined($limit) ? 1      : 0;

  my $options = optForClass($class);
  my $prefix  = $options->{prefix};

  if ( -d "$articleDir" && open( my $partsFH, "<", "$partsList" ) ) {
    my @attachments = ();
    print "<HR>\n" if main::print_article_warning( $newsgroup, $file );

    while ( my $part = <$partsFH> ) {
      my ( $filename, $type, $disposition ) = $part =~ m{^(\S+)\s+(\S+)\s+(\S+)$};
      if ( $disposition eq 'attachment' ) {
        push @attachments, { filename => $filename, type => $type };
        next;
      }
      if ( $type eq "text/plain" && $lineCount > 0 ) {
        my $quoted = [];
        print qq{<div class="pre $class">\n};
        open( my $FH, "$articleDir/$filename" );
        while ( my $line = <$FH> ) {
          if ( $line =~ m{\A>} ) {
            push( @$quoted, $line );
          } else {
            collapsible( "<i>%d quoted lines</i>", $quoted, $options );
            $quoted = [];
            print escape_html( $prefix->($line) );
            last if ( $lineCount -= $inc ) <= 0;
          }
        }
        close($FH);

        collapsible( "<i>%d quoted lines</i>\n", $quoted, $options );
        print "\n</div>\n\n";
      } else {
        print qq{<div><span class="hline">$type $filename</span></div>};
        print qq{<div>\n};
        inline_image( $linkbase, $filename, $type );
        print qq{</div>\n};
      }
    }
    close($partsFH);
    foreach my $a (@attachments) {
      my $afile = $a->{filename};
      my $link  = "$linkbase/$afile";
      my $type  = $a->{type};
      print(qq{<p>Attachment <a href="$link">$afile</a> $a->{type}</p>\n});
    }
  } else {
    print "This message ($articleDir) no longer exists -- maybe it was "
      . "approved or rejected by another moderator.";
  }
}

1;
