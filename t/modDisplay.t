#
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
# Tests for the Webstump::ModDisplay module. Run like this:
# prove -I webstump/scripts webstump/t/modDisplay.t

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Trap;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok( "Webstump::ModDisplay", qw(displayArticle) ) || return;
  test_modDisplay();
}

tests();
done_testing();

sub test_modDisplay {
  my $messageDir = "dir_001";
  my ($test_home) = $0 =~ m{^(.*)/modDisplay\.t$};
  ok( -d "$test_home/data/$messageDir", 'found test data' ) || return;
  my $url       = "http://example.com/";
  my $newsgroup = 'misc.test.moderated';
  my $normalCalls = {getQueueDir => 1, print_article_warning => 1};
  my @cases     = (
    {
      name  => 'multi 5 lines',
      class => 'multi',
      limit => 5,
      check => [
        { name => 'show summary', re => qr{<div class="summary">} },
        { name => 'hide full',    re => qr{<div class="full" style="display:none;">} },
        { name => 'line 3 shown',    re => qr{New text line 3} },
        { name => 'line 5 not shown',    re => qr{\A(?!.*New text line 5)} },
      ],
      calls => $normalCalls
    },
    {
      name  => 'multi 6 lines',
      class => 'multi',
      limit => 6,
      check => [
        { name => 'show summary', re => qr{<div class="summary">} },
        { name => 'hide full',    re => qr{<div class="full" style="display:none;">} },
        { name => 'line 5 shown',    re => qr{New text line 5} },
        { name => 'line 6 not shown',    re => qr{\A(?!.*New text line 6)} },
      ],
      calls => $normalCalls
    },
    {
      name  => 'single',
      class => 'single',
      limit => undef,
      check => [
        { name => 'show summary', re => qr{<div class="summary" style="display:none;">} },
        { name => 'hide full',    re => qr{<div class="full">} },
        { name => 'line 8 shown',    re => qr{New text line 8} },
      ],
      calls => $normalCalls
    }
  );
  foreach my $case (@cases) {
    my $class = $case->{class};
    my $limit = $case->{limit};
    my $calls = {};
    my $mock  = Test::MockModule->new( 'main', no_auto => 1 )->mock(
      getQueueDir           => sub { $calls->{getQueueDir}++;           return "$test_home/data"; },
      print_article_warning => sub { $calls->{print_article_warning}++; return (0); }
    );
    trap { displayArticle( $url, $newsgroup, $messageDir, $class, $limit ) };
    $trap->did_return(qq{$case->{name} normal return});
    foreach my $check ( @{ $case->{check} } ) {
      like( $trap->{stdout}, $check->{re}, "$case->{name} $check->{name}" );
    }
    is_deeply( $calls, $case->{calls}, qq{$case->{name} makes expected calls} )
      or diag( explain($calls) );
  }
}
