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
  readUsers
  saveUsers
  updateUsers
  isListAdmin
  isUserAdmin
  isFullAdmin
  isAdmin
  isModerator
  getRights
);

my @adminRights = (qw{fullAdmin listAdmin userAdmin});

sub isListAdmin {
  my ($user) = @_;
  return $user->{listAdmin} || $user->{fullAdmin};
}

sub isUserAdmin {
  my ($user) = @_;
  return $user->{userAdmin} || $user->{fullAdmin};
}

sub isFullAdmin {
  my ($user) = @_;
  return $user->{fullAdmin};
}

sub isAdmin {
  my ($user) = @_;
  return $user->{userAdmin} || $user->{listAdmin} || $user->{fullAdmin};
}

sub isModerator {
  my ($user) = @_;
  return $user->{moderate};
}

sub getRights {
  return ( 'moderate', @adminRights );
}

# TODO combine this with authentication
sub userData {
  my $id    = uc( $main::request{moderator} // q{} );
  my $users = $main::users;
  if ( exists( $users->{$id} ) ) {
    return $users->{$id};
  }
  return {};
}

sub addUser {
  my ( $users, $id, $pw, $request ) = @_;
  my $user = { id => $id, pw => $pw };
  updateUserRights( $request, $user, 'new' );
  $users->{$id} = $user;
}

sub changePassword {
  my ( $users, $id, $new_password ) = @_;
  $users->{$id}->{pw} = $new_password;
}

sub deleteUser {
  my ( $users, $id ) = @_;
  delete $users->{$id};
}

sub readUsers {
  my ( $fh, $legacy ) = @_;
  my $users = {};
  while ( my $rawline = <$fh> ) {
    my ($line) = $rawline =~ m{\A([\w\s]+)\z};
    next unless $line;
    my ( $id, $pw, @rights ) = split( qr{\s}, $line );
    $users->{$id} = { id => $id, pw => $pw, map { ( $_ => 1 ) } @rights };
    foreach my $right ( getRights() ) {
      $users->{$id}->{$right} //= 0;
    }
  }
  if ($legacy) {
    foreach my $id ( keys(%$users) ) {
      fixLegacyPermissions( $users->{$id} );
    }
  }
  return $users;
}

sub fixLegacyPermissions {
  my ($user) = @_;
  if ( my $id = $user->{id} ) {
    my $admin = ( $id =~ m{^admin$}i ) ? 1 : 0;
    foreach my $right (@adminRights) {
      $user->{$right} = $admin;
    }
    $user->{moderate} = 1 - $admin;
  }
}

sub readUsersFromFile {
  my $dir = main::full_config_dir_name();
  if ( -r "$dir/users" ) {
    open( my $fh, '<', "$dir/users" ) || main::error("open < $dir/users $!");
    my $users = readUsers($fh);
    close $fh;
    return $users;
  }

  # fall back to legacy moderators file
  open( my $fh, '<', "$dir/moderators" ) || main::error("open < $dir/moderators $!");
  my $users = readUsers( $fh, 1 );
  close $fh;
  saveUsersToFile($users);
  return $users;
}

sub saveUsers {
  my ( $users, $fh ) = @_;
  foreach my $userId ( sort( keys(%$users) ) ) {
    my $user   = $users->{$userId};
    my @rights = map { $user->{$_} ? $_ : () } ( getRights() );
    printf $fh "%s %s %s\n", $user->{id}, $user->{pw}, join( q{ }, @rights );
  }
}

sub saveUsersToFile {
  my ($users) = @_;
  my $dir     = main::full_config_dir_name();
  my $file    = "$dir/users";
  open( my $fh, '>', $file ) || main::error("open > $file $!");
  saveUsers( $users, $fh );
  close $fh;
}

sub updateUserRights {
  my ( $request, $user, $id ) = @_;
  foreach my $right ( getRights() ) {
    $user->{$right} = $request->{"$id-$right"} ? 1 : 0;
  }
}

sub updateUsers {
  my ( $request, $newsgroup, $users ) = @_;
  if ( my $deleteUser = $request->{deleteUser} ) {
    delete $users->{$deleteUser};
  } else {
    foreach my $id ( keys(%$users) ) {
      updateUserRights( $request, $users->{$id}, $id );
    }
    if ( my $addUser = $request->{"new-user"} ) {
      my $id = uc($addUser);
      my $pw = uc( $request->{"new-pw"} // q{} );
      addUser( $users, $id, $pw, $request );
    }
  }
  saveUsersToFile($users);
}
1;
