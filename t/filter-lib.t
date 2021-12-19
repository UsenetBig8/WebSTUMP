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
# Tests for the filter.lib.pl library.
# Run like this:
# prove -I webstump/scripts webstump/t/filter-lib.t

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
  require_ok("filter.lib.pl") || return;
  test_process_approval_decision();
}

tests();
done_testing();

sub test_process_approval_decision {
  my $case = 'process_approval_decision';
  my $calls = {};
  my @mocklist = (qw(email_message rmdir_rf article_file_name decisionForSTUMP) );
  my $mock = Test::MockModule->new( 'main', no_auto => 1 );
  foreach my $fn (@mocklist) {
    $mock->mock( $fn => sub { $calls->{$fn}++; } );
  };
  my $subject = "The Subject";
  my $newsgroup = "m.t.m";
  my $dir = "dir";
  my $decision = "reject charter";
  my $comment = "mod comment";
  my $expectCalls = { map { $_ => 1 } @mocklist };
  trap { process_approval_decision($subject, $newsgroup, $dir, $decision, $comment) };
  $trap->did_return(qq{$case normal return});
  is_deeply($calls, $expectCalls, "$case expected calls") or
    diag(explain($calls));
}
