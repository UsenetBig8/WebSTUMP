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
package Webstump::User;

# Functions related to users (moderators)

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(
  userData
);

# TODO combine this with authentication
sub userData {
  # TODO look up user rights and add to the hash
  # In preparation for giving admin rights to users
  # For now use the id to determine rights
  my $id = $main::request{moderator} // q{};
  my $user = {
    id => $id,
    pw => $main::request{password} // q{},
  };
  if ($id =~ m{^admin$}i) {
    $user->{fullAdmin} = 1,
    $user->{moderate} = 0
  } elsif ($id) {
    $user->{fullAdmin} = 0,
    $user->{moderate} = 1
  }
  return $user;
}

1;