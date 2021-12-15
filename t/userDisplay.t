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
# Tests for the Webstump::UserDisplay module. Run like this:
# prove -I webstump/scripts webstump/t/userDisplay.t

use strict;
use warnings;

use Test::More;
use Test::Trap;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok( "Webstump::UserDisplay", qw(
    userManagementForm changePasswordForm
  ) ) || return;
  test_userManagementForm();
  test_userManagementForm_listAdmin();
  test_changePasswordForm();
}

tests();
done_testing();

sub test_userManagementForm {
  my $case = 'userManagementForm userAdmin';
  my $newsgroup = "m.t.m";
  my $url = "http://example.com/";
  my $users = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
  };
  my $user = $users->{USER1};
  our $trap;
  local $trap;
  trap { userManagementForm( $url, $newsgroup, $user, $users ) };
  $trap->did_return(qq{$case normal return});
  my $file = $trap->{stdout};
  like($file, qr{\A\s*<div class="currentUsers".*</div>\s*\z}s, qq{$case div wrapper});
  like($file, qr{<form action="$url" }, qq{$case form action url});
  like($file, qr{<input name="action" value="updateUsers" }, qq{$case input action value});
  like($file, qr{\A(?!.*<button name="deleteUser" value="ADMIN">)}, qq{$case no ADMIN delete user button});
  like($file, qr{<td><button name="deleteUser" value="USER1">Delete USER1</button></td>}, qq{$case USER1 delete user button});
  like($file, qr{\A(?!.*<button name="newPassword" value="ADMIN">)}, qq{$case no ADMIN change pw button});
  like($file, qr{<td><button name="newPassword" value="USER1">Change PW</button></td>}, qq{$case USER1 change pw button});
  like($file, qr{\A(?!.*<input[^>]*name="ADMIN-moderate")}, qq{$case no ADMIN moderate input});
  like($file, qr{<input type="hidden" name="ADMIN-fullAdmin" value="on"}, qq{$case ADMIN fullAdmin input});
  like($file, qr{<input type="checkbox" name="USER1-moderate" checked>}, qq{$case USER1 moderate checkbox});
  like($file, qr{<input type="checkbox" name="USER3-fullAdmin">}, qq{$case USER3 fullAdmin checkbox});
  like($file, qr{<input type="text" size="8" name="new-user" value="">}, qq{$case new user name input field});
  like($file, qr{<input type="password" size="8" name="new-pw" value="">}, qq{$case new user password input field});
  like($file, qr{<input type="checkbox" name="new-moderate">}, qq{$case new user moderate checkbox});
  like($file, qr{<input type="checkbox" name="new-fullAdmin">}, qq{$case new user fullAdmin checkbox});
  like($file, qr{<button type="submit" name="update" value="update">Update</button>}, qq{$case submit button});
}

sub test_userManagementForm_listAdmin {
  my $case = 'userManagementForm listAdmin';
  my $newsgroup = "m.t.m";
  my $url = "http://example.com/";
  my $users = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
  };
  my $user = $users->{USER2};
  our $trap;
  local $trap;
  trap { userManagementForm( $url, $newsgroup, $user, $users ) };
  $trap->did_return(qq{$case normal return});
  my $file = $trap->{stdout};
  like($file, qr{\A\z}s, qq{$case prints nothing});
}

sub test_changePasswordForm {
  my $case = 'changePasswordForm';
  my $newsgroup = "m.t.m";
  my $url = "http://example.com/";
  my $users = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
  };
  my $user = $users->{USER1};
  my $userToChange = 'USER3';
  our $trap;
  local $trap;
  trap { changePasswordForm( $url, $newsgroup, $user, $users, $userToChange ) };
  $trap->did_return(qq{$case normal return});
  my $file = $trap->{stdout};
  like($file, qr{<h2>Changing password for USER3</h2>}s, qq{$case h2 header});
  like($file, qr{<form action="$url" }, qq{$case form action url});
  like($file, qr{<input name="action" value="validate_change_password"}, qq{$case input action value});
  like($file, qr{<label for="newpw">New Password for USER3: </label>}, qq{$case label for password input});
  like($file, qr{<input type="password" id="newpw" size="10" name="USER3-pw" value="">}, qq{$case password input field});
  like($file, qr{<button type="submit" name="update" value="USER3">Update password for USER3</button>}, qq{$case USER3 change pw button});  
}