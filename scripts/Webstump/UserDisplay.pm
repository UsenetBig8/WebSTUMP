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
package Webstump::UserDisplay;

# Functions to output HTML related to user management

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(
  changePasswordForm
  userManagementForm
  addUserForm
);
use HTML::Escape qw/escape_html/;
use Webstump::Display qw(credentials);
use Webstump::User qw(getRights isUserAdmin);

sub userManagementForm {
  my ( $url, $newsgroup, $user, $users ) = @_;

  # Show the form only if user has user admin rights
  return if !isUserAdmin($user);

  my $hurl = escape_html($url);
  print qq{<div class="currentUsers">\n};
  print qq{<form action="$hurl" method="post">\n};
  print qq{<input name="action" value="updateUsers" type="hidden">\n};
  credentials( $newsgroup, $user );
  print qq{<table><caption>Update user data</caption>\n};
  print qq{<tr>};
  print qq{<th></th>};
  print qq{<th>Name</th>};
  print qq{<th>Password</th>};

  foreach my $r ( getRights() ) {
    printf qq{<th>%s</th>}, escape_html($r);
  }
  print qq{</tr>\n};
  foreach my $id ( sort( keys(%$users), 'new' ) ) {
    my $u   = $users->{$id};
    my $hid = escape_html( $id );
    print qq{<tr>};
    if ( $id eq 'new' ) {
      print qq{<td>Add User</td>};
      print qq{<td><input type="text" size="8" name="new-user" value=""></td>};
      print qq{<td><input type="password" size="8" name="new-pw" value=""></td>};
    } else {

      # TODO configurable option to allow ADMIN password change and delete
      # That requires changes elsewhere too.
      if ( $id eq "ADMIN" ) {
        print qq{<td></td>};
        print qq{<td>$hid</td>};
        print qq{<td></td>};
      } else {
        print qq{<td><button name="deleteUser" value="$hid">Delete $hid</button></td>};
        print qq{<td>$hid</td>};
        print
          qq{<td><button name="newPassword" value="$hid">Change PW</button></td>};
      }
    }
    foreach my $r ( getRights() ) {
      print qq{<td>};
      my $set = $u->{$r} ? " checked" : q{};
      if ( $id eq "ADMIN" ) {

        # This shows disabled checkboxes for ADMIN but also submits
        # as if the checked ones were not disabled.
        if ( $u->{$r} ) {
          printf qq{<input type="hidden" name="%s-%s" value="on">}, $hid, escape_html($r);
        }
        print qq{<input type="checkbox" $set disabled>};
      } else {
        printf qq{<input type="checkbox" name="%s-%s"$set>}, $hid, escape_html($r);
      }
      print qq{</td>};
    }
    print qq{</tr>\n};
  }

  print qq{</table>\n};
  print qq{<button type="submit" name="update" value="update">Update</button>\n};
  print qq{</form>\n};
  print qq{</div>\n};
}

sub changePasswordForm {
  my ( $url, $newsgroup, $user, $users, $userToChange ) = @_;
  my $hid     = escape_html( $user->{id} );
  my $hurl    = escape_html($url);
  my $hChange = escape_html($userToChange);
  my $pwFor   = $userToChange eq $user->{id} ? q{} : qq{ for $hChange};
  print qq{<h2>Changing password for $hChange</h2>\n};
  print qq{<p>All usernames and passwords are not case sensitive.</p>\n};
  print qq{<form action="$hurl" method="post">\n};
  print qq{<input name="action" value="validate_change_password", type="hidden">\n};
  credentials( $newsgroup, $user );
  printf qq{<p><label for="newpw">New Password for $hChange: </label>};
  print qq{<input type="password" id="newpw" size="10" name="${hChange}-pw" value=""></p>\n};
  print
qq{<button type="submit" name="update" value="$hChange">Update password for $hChange</button>\n};
  print qq{</form>\n};
}

1;
