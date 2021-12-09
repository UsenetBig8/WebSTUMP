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
# Tests for the Webstump::User module. Run like this:
# prove -I webstump/scripts webstump/test/user.t

use strict;
use warnings;

use Test::More;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok("Webstump::User", qw(userData)) || return;
  test_userData();
}

tests();
done_testing();

sub test_userData {
  can_ok( "Webstump::User", 'userData' ) || return;
  test_userData_admin();
  test_userData_moderator();
  test_userData_loggedout();
}

sub test_userData_admin {
  foreach my $id (qw(admin ADMIN Admin)) {
    my $modpw = 'admin1234';
    %main::request = (
      moderator => $id,
      password  => $modpw
    );
    my $expected = {
      id        => $id,
      pw        => $modpw,
      fullAdmin => 1,
      moderate  => 0
    };
    my $got = userData();
    is_deeply( $got, $expected, "admin user $id rights" ) ||
      diag(explain($got));
  }
}

sub test_userData_moderator {
  my $id = 'mod';
  my $pw = 'mod1234';
  %main::request = (
    moderator => $id,
    password  => $pw
  );
  my $expected = {
    id        => $id,
    pw        => $pw,
    fullAdmin => 0,
    moderate  => 1
  };
  my $got = userData();
  is_deeply( $got, $expected, "moderator user $id rights" ) ||
      diag(explain($got));
}
sub test_userData_loggedout {
  %main::request = ();
  my $expected = {
    id        => q{},
    pw        => q{},
  };
  my $got = userData();
  is_deeply( $got, $expected, "loggedout no id/pw" ) ||
      diag(explain($got));
}

