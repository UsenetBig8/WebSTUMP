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
# Tests for the html_output.pl library.
# Run like this:
# prove -I webstump/scripts webstump/t/html_output.t

#

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Trap;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  require_ok("html_output.pl") || return;
  test_html_newsgroup_management();
}

tests();
done_testing();

sub test_html_newsgroup_management {
  my $case = 'html_newsgroup_management';
  our $trap;
  local $trap;
  my @mocklist = (
    qw(begin_html end_html exitButtons userData userManagementForm isListAdmin listManagementForm));
  my $calls = {};
  my $mock  = Test::MockModule->new( 'main', no_auto => 1 )->mock(
    map {
      my $f = $_;
      ( $f => sub { $calls->{$f}++ } )
    } @mocklist
  );
  my $expectCalls = {
    'begin_html'         => 1,
    'end_html'           => 1,
    'exitButtons'        => 1,
    'listManagementForm' => 1,
    'userData'           => 1,
    'userManagementForm' => 1

  };
  trap { html_newsgroup_management( 'm.t.m.', {} ) };
  $trap->did_return(qq{$case normal return});
  my $got = $trap->{stdout};
  like( $got, qr{\A\z}, qq{$case no output} );
  is_deeply( $calls, $expectCalls, qq{$case makes expected calls} )
    or diag( explain($calls) );

}
