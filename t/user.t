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
# prove -I webstump/scripts webstump/t/user.t

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Trap;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok(
    "Webstump::User", qw(
      userData readUsers saveUsers updateUsers
      isListAdmin isUserAdmin isFullAdmin isAdmin isModerator
      getRights
      )
  ) || return;
  test_userData();
  test_fixLegacyPermissions();
  test_rights_accessors();
  test_readUsers();
  test_readUsers_legacy();
  test_saveUsers();
  test_changePassword();
  test_updateUsers();
  test_readUsersFromFile();
  test_saveUsersToFile();
}

tests();
done_testing();

sub test_userData {
  can_ok( "Webstump::User", 'userData' ) || return;
  test_userData_undef();
  test_userData_known();
}

sub test_userData_undef {
  %main::request = (
    moderator => 'admin',
    password  => 'admin1234'
  );
  my $expected = {};
  my $got      = userData();
  is_deeply( $got, $expected, "userData not known" )
    || diag( explain($got) );
}

sub test_userData_known {
  my $pw = 'mod1234';
  $main::users = {
    MOD => {
      id        => "MOD",
      pw        => "MOD1234",
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0,
      moderate  => 1
    }
  };
  my $expected = $main::users->{MOD};
  foreach my $id (qw(mod Mod MOD)) {
    %main::request = (
      moderator => $id,
      password  => $pw
    );
    my $got = userData();
    is_deeply( $got, $expected, "userData known id $id found" )
      || diag( explain($got) );
  }
}

sub test_userData_loggedout {
  %main::request = ();
  my $expected = {
    id => q{},
    pw => q{},
  };
  my $got = userData();
  is_deeply( $got, $expected, "loggedout no id/pw" )
    || diag( explain($got) );
}

# Note that fixLegacyPermissions adds the permissions based on the id
# but does not change anything else.
sub test_fixLegacyPermissions {
  my %admin = ( fullAdmin => 1, listAdmin => 1, userAdmin => 1, moderate => 0 );
  my %mod   = ( fullAdmin => 0, listAdmin => 0, userAdmin => 0, moderate => 1 );
  foreach my $id (qw(admin ADMIN Admin)) {
    my $modpw    = 'admin1234';
    my $user     = { id => $id, pw => $modpw };
    my $expected = { id => $id, pw => $modpw, %admin };
    Webstump::User::fixLegacyPermissions($user);
    is_deeply( $user, $expected, "fixLegacyPermissions admin user $id" )
      || diag( explain($user) );
  }
  {
    my $user     = { id => 'MOD', pw => 'MODPW' };
    my $expected = { id => 'MOD', pw => 'MODPW', %mod };
    Webstump::User::fixLegacyPermissions($user);
    is_deeply( $user, $expected, "fixLegacyPermissions moderator" )
      || diag( explain($user) );
  }
  {
    my $user     = {};
    my $expected = {};
    Webstump::User::fixLegacyPermissions($user);
    is_deeply( $user, $expected, "fixLegacyPermissions moderator" )
      || diag( explain($user) );
  }
}

sub test_rights_accessors {
  foreach my $m ( ( 0, 1 ) ) {
    foreach my $f ( ( 0, 1 ) ) {
      foreach my $l ( ( 0, 1 ) ) {
        foreach my $u ( ( 0, 1 ) ) {
          my $user = {
            id        => 'U',
            pw        => 'PW',
            moderate  => $m,
            fullAdmin => $f,
            listAdmin => $l,
            userAdmin => $u
          };
          is( isListAdmin($user), $f || $l, "isListAdmin m=$m f=$f l=$l u=$u" );
          is( isUserAdmin($user), $f || $u, "isUserAdmin m=$m f=$f l=$l u=$u" );
          is( isFullAdmin($user), $f,             "isFullAdmin m=$m f=$f l=$l u=$u" );
          is( isAdmin($user),     $f || $l || $u, "isAdmin m=$m f=$f l=$l u=$u" );
          is( isModerator($user), $m,             "isModerator m=$m f=$f l=$l u=$u" );

        }
      }
    }
  }

  # Other tests will fail if the list of rights in not in this order
  my $expectRights = [qw(moderate fullAdmin listAdmin userAdmin)];
  is_deeply( [ getRights() ], $expectRights, 'getRights' );
}

sub test_readUsers {
  my $file = <<"END";
ADMIN APW fullAdmin listAdmin userAdmin
USER1 U1PW moderate fullAdmin listAdmin
USER2 U2PW moderate listAdmin

USER3 U3PW moderate

END
  my $expect = {
    ADMIN => {
      id        => 'ADMIN',
      pw        => 'APW',
      moderate  => 0,
      fullAdmin => 1,
      listAdmin => 1,
      userAdmin => 1
    },
    USER1 => {
      id        => 'USER1',
      pw        => 'U1PW',
      moderate  => 1,
      fullAdmin => 1,
      listAdmin => 1,
      userAdmin => 0
    },
    USER2 => {
      id        => 'USER2',
      pw        => 'U2PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 1,
      userAdmin => 0
    },
    USER3 => {
      id        => 'USER3',
      pw        => 'U3PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0
    },
  };
  open( my $fh, '<', \$file ) || die "open > file $!";
  my $users = readUsers($fh);
  close $fh;
  is_deeply( $users, $expect, 'readUsers' )
    or diag( explain($users) );
}

sub test_readUsers_legacy {
  my $file = <<"END";
ADMIN APW
USER1 U1PW
USER2 U2PW
USER3 U3PW
END
  my $expect = {
    ADMIN => {
      id        => 'ADMIN',
      pw        => 'APW',
      moderate  => 0,
      fullAdmin => 1,
      listAdmin => 1,
      userAdmin => 1
    },
    USER1 => {
      id        => 'USER1',
      pw        => 'U1PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0
    },
    USER2 => {
      id        => 'USER2',
      pw        => 'U2PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0
    },
    USER3 => {
      id        => 'USER3',
      pw        => 'U3PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0
    },
  };
  open( my $fh, '<', \$file ) || die "open > file $!";
  my $users = readUsers( $fh, 1 );
  close $fh;
  is_deeply( $users, $expect, 'readUsers legacy' )
    or diag( explain($users) );
}

sub test_saveUsers {
  my $users = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1, userAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate  => 1 },
  };
  my $expect = <<"END";
ADMIN APW fullAdmin listAdmin userAdmin
USER1 U1PW moderate fullAdmin listAdmin
USER2 U2PW moderate listAdmin
USER3 U3PW moderate
END
  my $file;
  open( my $fh, '>', \$file ) || die "open > file $!";
  saveUsers( $users, $fh );
  close $fh;
  is( $file, $expect, 'saveUsers' );
}

sub test_changePassword {
  my $users = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
  };
  my $expect = {
    ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
    USER1 => { id => 'USER1', pw => 'U1NP', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
    USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
    USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
  };
  Webstump::User::changePassword( $users, 'USER1', 'U1NP' );
  is_deeply( $users, $expect, 'changePassword' )
    or diag( explain($users) );
}

sub test_updateUsers {
  my $test        = 'updateUsers';
  my $requestBase = {
    moderator => 'ADMIN',
    password  => 'ADMINPW',
    action    => 'updateUsers',
    newsgroup => 'm.t.m',
    update    => 'update',
  };
  my @cases = (
    {
      name     => 'no change',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
        USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
        USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "USER2-moderate"  => 'on',
        "USER2-listAdmin" => 'on',
        "USER3-moderate"  => 'on',
        "new-user"        => q{},
        "new-pw"          => q{},
      },
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 1,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      name     => 'delete all rights',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
        USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
        USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
      },
      req    => {},
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 0,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 0,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 0,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      name     => 'users moderate only',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
        USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
        USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER2-moderate"  => 'on',
        "USER3-moderate"  => 'on',

      },
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      name     => 'add admin to moderator USER1',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1 },
        USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1 },
        USER3 => { id => 'USER3', pw => 'U3PW', moderate  => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "USER2-moderate"  => 'on',
        "USER3-moderate"  => 'on',

      },
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      name     => 'add moderator',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
        USER2 => { id => 'USER2', pw => 'U2PW', moderate  => 1, listAdmin => 1 },
        USER3 => { id => 'USER3', pw => 'U3PW', moderate => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "USER2-moderate"  => 'on',
        "USER2-listAdmin" => 'on',
        "USER3-moderate"  => 'on',
        "new-user"        => q{fred},
        "new-pw"          => q{fredpw},
        "new-moderate"    => 'on',
      },
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        FRED => {
          id        => 'FRED',
          pw        => 'FREDPW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 1,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      name     => 'delete USER3',
      userBase => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 1,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'U3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "USER2-moderate"  => 'on',
        "deleteUser"      => q{USER3},
      },
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'APW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'U1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'U2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 1,
          userAdmin => 0
        }
      }
    },
    {
      name     => 'add user without password',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "new-user"        => q{fred},
        "new-pw"          => q{},
        "new-moderate"    => 'on',
      },
      error => {
        calls => { user_error => ['New user fred must have a password'] },
      }
    },
    {
      name     => 'delete ADMIN user',
      userBase => {
        ADMIN => { id => 'ADMIN', pw => 'APW',  fullAdmin => 1, listAdmin => 1 },
        USER1 => { id => 'USER1', pw => 'U1PW', moderate  => 1, fullAdmin => 1, listAdmin => 1 },
      },
      req => {
        "ADMIN-fullAdmin" => 'on',
        "ADMIN-listAdmin" => 'on',
        "USER1-moderate"  => 'on',
        "USER1-fullAdmin" => 'on',
        "USER1-listAdmin" => 'on',
        "deleteUser"      => q{ADMIN},
      },
      error => {
        calls => { user_error => ['User ADMIN cannot be deleted'] },
      }
    },

  );
  foreach my $case (@cases) {
    my $testcase = "$test $case->{name}";
    my $calls    = {};
    my $mock     = Test::MockModule->new( 'Webstump::User', no_auto => 1 )
      ->mock( saveUsersToFile => sub { $calls->{saveUsersToFile} = [@_]; } );
    my $mockMain = Test::MockModule->new( 'main', no_auto => 1 )
      ->mock( user_error => sub { $calls->{user_error} = [@_]; exit(0); } );

  TODO: {
      local $TODO = $case->{todo};
      my $users = { %{ $case->{userBase} } };             # shallow copy
      my %req   = ( %$requestBase, %{ $case->{req} } );
      trap { updateUsers( \%req, 'm.t.m', $users ) };
      if ( my $error = $case->{error} ) {
        $trap->did_exit(qq{$testcase did exit});
        is_deeply( $calls, $error->{calls}, qq{$testcase made expected calls} )
          or diag( explain($calls) );
      } else {
        $trap->did_return(qq{$testcase normal return});
        is_deeply( $users, $case->{expect}, "$testcase updated users" )
          or diag( explain($users) );
        is_deeply( $calls, { saveUsersToFile => [$users] }, qq{$testcase called saveUsersToFile} );
      }
    }
  }
}

sub test_readUsersFromFile {
  my $test  = 'readUsersFromFile';
  my @cases = (
    {
      case   => 'users file',
      ng     => 'm.t.m',
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'ADMINPW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 1
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'USER1PW',
          moderate  => 1,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 0
        },
        USER2 => {
          id        => 'USER2',
          pw        => 'USER2PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 1,
          userAdmin => 0
        },
        USER3 => {
          id        => 'USER3',
          pw        => 'USER3PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        },
      }
    },
    {
      case   => 'moderators file',
      ng     => 'm.t.legacy',
      expect => {
        ADMIN => {
          id        => 'ADMIN',
          pw        => 'ADMINPW',
          moderate  => 0,
          fullAdmin => 1,
          listAdmin => 1,
          userAdmin => 1
        },
        USER1 => {
          id        => 'USER1',
          pw        => 'USER1PW',
          moderate  => 1,
          fullAdmin => 0,
          listAdmin => 0,
          userAdmin => 0
        }
      },
      calls => { saveUsersToFile => 1 }
    }
  );

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");

  foreach my $case (@cases) {
    my $testcase = "$test $case->{case}";

    my ($test_home) = $0 =~ m{^(.*)/user\.t$};
    ok( -d "$test_home/data/config/", qq{$testcase found test data} ) || return;

    # declare these variables separately to avoid the used once warning
    local ( $main::webstump_home, %main::request );
    $main::webstump_home = qq{$test_home/data};
    %main::request       = ( newsgroup => $case->{ng} );
    my $calls = {};
    my $mock  = Test::MockModule->new( 'Webstump::User', no_auto => 1 )
      ->mock( saveUsersToFile => sub { $calls->{saveUsersToFile}++; } );

    my $users = trap { Webstump::User::readUsersFromFile() };
    $trap->did_return(qq{$testcase normal return});
    is_deeply( $users, $case->{expect}, qq{$testcase expecte result} )
      or diag( explain($users) );
    is_deeply( $calls, $case->{calls} // {}, qq{$testcase made expected calls} )
      or diag( explain($calls) );
  }
}

sub test_saveUsersToFile {
  my $test      = 'saveUsersToFile';
  my $tempdir   = tempdir( CLEANUP => 1 );
  my $newsgroup = 'm.t.m';
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = $tempdir;
  %main::request       = ( newsgroup => $newsgroup );
  my $configdir = "$tempdir/config/newsgroups/$newsgroup/";

  my @dirs = make_path("$configdir");
  if ( !scalar(@dirs) ) { die "failed to create $configdir $!" }
  my $users = {
    ADMIN => {
      id        => 'ADMIN',
      pw        => 'APW',
      moderate  => 0,
      fullAdmin => 1,
      listAdmin => 1,
      userAdmin => 0
    },
    USER1 => {
      id        => 'USER1',
      pw        => 'U1PW',
      moderate  => 1,
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0
    },
  };
  my $expect = qq{ADMIN APW fullAdmin listAdmin\nUSER1 U1PW moderate\n};
  trap { Webstump::User::saveUsersToFile($users) };
  $trap->did_return(qq{$test normal return});
  open( my $infh, '<', "$configdir/users" ) || die "failed to open < $configdir/users $!";
  my $data = do { local $/; <$infh> };
  close($infh);
  is( $data, $expect, qq{$test saved file has expected data} );

}
