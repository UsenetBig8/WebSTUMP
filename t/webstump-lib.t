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
# Tests for the webstump.lib.pl library.
# Run like this:
# prove -I webstump/scripts webstump/t/webstump-lib.t

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
  require_ok("webstump.lib.pl") || return;
  test_processWebRequest();
}

tests();
done_testing();

sub test_processWebRequest {
  our $users;
  local $users = {
    ADMIN => {
      id        => 'ADMIN',
      pw        => "ADMINPW",
      fullAdmin => 1,
      listAdmin => 1,
      userAdmin => 1,
      moderate  => 0
    },
    USER1 => {
      id        => 'USER1',
      pw        => "USER1PW",
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 0,
      moderate  => 1
    },
    USER2 => {
      id        => 'USER2',
      pw        => "USER2PW",
      fullAdmin => 0,
      listAdmin => 1,
      userAdmin => 0,
      moderate  => 0
    },
    USER3 => {
      id        => 'USER3',
      pw        => "USER3PW",
      fullAdmin => 0,
      listAdmin => 0,
      userAdmin => 1,
      moderate  => 0
    }
  };
  my %requestForUser = (
    loggedout => { rights => 'loggedout', req => { newsgroup => 'm.t.m' } },
    admin     => {
      rights => 'fullAdmin',
      req    => { newsgroup => 'm.t.m', moderator => 'ADMIN', password => "ADMINPW" }
    },
    gooduser => {
      rights => 'moderator',
      req    => { newsgroup => 'm.t.m', moderator => 'USER1', password => "USER1PW" }
    },
    baduser => {
      rights => 'loggedout',
      req    => { newsgroup => 'm.t.m', moderator => 'USER1', password => "BADPW" }
    },
    listAdmin => {
      rights => 'listAdmin',
      req    => { newsgroup => 'm.t.m', moderator => 'USER2', password => "USER2PW" }
    },
    userAdmin => {
      rights => 'userAdmin',
      req    => { newsgroup => 'm.t.m', moderator => 'USER3', password => "USER3PW" }
    }
  );

  # Expected call for all authenticated actions
  my %auth = ( readUsersFromFile => 1 );

  # return to management page
  my %manage = ( html_newsgroup_management => 1 );

  # result to expect if there are no expected calls for the action
  my %nocalls = (
    loggedout => {
      wslog => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
      calls  => { %auth, user_error => 1 }
    },
    admin => {
      wslog  => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s,            case => 'exit(0)' } ],
      calls => { %auth, user_error => 1 }
    },
    gooduser => {
      wslog  => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s,            case => 'exit(0)' } ],
      calls => { %auth, user_error => 1 }
    },
    baduser => {
      wslog =>
        [ { re => qr{SECURITY_ALERT: Authentication denied}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
      calls  => { %auth, user_error => 1 }
    },
    listAdmin => {
      wslog  => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s,            case => 'exit(0)' } ],
      calls => { %auth, user_error => 1 }
    },
    userAdmin => {
      wslog  => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s,            case => 'exit(0)' } ],
      calls => { %auth, user_error => 1 }
    },
  );

  # Map of actions to functions expected to be called for kind of user
  my %actions = (
    moderation_screen => {
      fullAdmin => { %auth, %manage },
      listAdmin => { %auth, %manage },
      userAdmin => { %auth, %manage },
      moderator => { %auth, html_moderation_screen => 1 }
    },
    approval_decision => { moderator => { %auth, approval_decision     => 1 } },
    moderate_article  => { moderator => { %auth, html_moderate_article => 1 } },
    management_screen => {
      fullAdmin => { %auth, %manage },
      listAdmin => { %auth, %manage },
      userAdmin => { %auth, %manage }
    },
    updateUsers => {
      fullAdmin => { %auth, updateUsers => 1, %manage },
      userAdmin => { %auth, updateUsers => 1, %manage }
    },
    edit_list => {
      fullAdmin => { %auth, edit_configuration_list => 1 },
      listAdmin => { %auth, edit_configuration_list => 1 }
    },
    manageRejectionReasons => {
      fullAdmin => { %auth, manageRejectionReasons => 1 },
      listAdmin => { %auth, manageRejectionReasons => 1 }
    },
    add_user => {
      fullAdmin => { %auth, add_user => 1, %manage },
      userAdmin => { %auth, add_user => 1, %manage }
    },
    set_config_list => {
      fullAdmin => { %auth, set_config_list => 1, %manage },
      listAdmin => { %auth, set_config_list => 1, %manage },
    },
    manage_bad_newsgroups_header => {
      fullAdmin => { %auth, manage_bad_newsgroups_header => 1 },
      listAdmin => { %auth, manage_bad_newsgroups_header => 1 }
    },
    manage_bad_newsgroups_header_set => {
      fullAdmin => {
        %auth,
        manage_bad_newsgroups_header_set => 1,
        html_newsgroup_management        => 1
      },
      listAdmin => {
        %auth,
        manage_bad_newsgroups_header_set => 1,
        html_newsgroup_management        => 1
      }
    },
    manage_bad_newsgroups_header_cancel =>
      { fullAdmin => { %auth, %manage }, listAdmin => { %auth, %manage } },
    delete_user => {
      fullAdmin => { %auth, delete_user => 1, %manage },
      userAdmin => { %auth, delete_user => 1, %manage }
    },
    change_password => {
      fullAdmin => { %auth, html_change_password => 1 },
      listAdmin => { %auth, html_change_password => 1 },
      userAdmin => { %auth, html_change_password => 1 },
      moderator => { %auth, html_change_password => 1 }
    },
    validate_change_password => {
      fullAdmin => { %auth, validate_change_password => 1 },
      listAdmin => { %auth, validate_change_password => 1 },
      userAdmin => { %auth, validate_change_password => 1 },
      moderator => { %auth, validate_change_password => 1 }
    },
    login_screen                        => { all => { html_login_screen                   => 1 } },
    init_request_newsgroup_creation     => { all => { init_request_newsgroup_creation     => 1 } },
    complete_newsgroup_creation_request => { all => { complete_newsgroup_creation_request => 1 } },
    webstump_admin_screen               => { all => { webstump_admin_screen               => 1 } },
    admin_login                         => { all => { admin_login_screen                  => 1 } },
    admin_add_newsgroup                 => { all => { admin_add_newsgroup                 => 1 } },
    help                                => { all => { display_help                        => 1 } },
    unknown                             => {
      nocalls => {
        'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
        calls  => { error => 1 }
      }
    }
  );
  my $makeCase = sub {
    my ( $action, $user ) = @_;
    my $rights  = $requestForUser{$user}->{rights};
    my $calls   = $actions{$action}->{$rights} || $actions{$action}->{all};
    my $nocalls = $actions{$action}->{nocalls} || $nocalls{$user};
    return {
      name   => "$action $user",
      req    => { action => $action, %{ $requestForUser{$user}->{req} } },
      stdout => [ { re => qr{^$}s, case => 'no STDOUT' } ],
      stderr => [ { re => qr{^$}s, case => 'no STDERR' } ],
      ( $calls ? ( calls => $calls ) : %$nocalls )
    };
  };

  # Note that if the module under test imports a function you have to mock it in the
  # package of the module under test rather than it's 'home' package - 'main' in this case
  # for updateUsers. No harm in mocking in both places.
  my @mocklist = (
    qw(
      read_moderators
      html_login_screen html_moderation_screen html_newsgroup_management
      add_user edit_configuration_list set_config_list manage_bad_newsgroups_header
      manage_bad_newsgroups_header_set delete_user approval_decision
      html_moderate_article html_change_password validate_change_password
      init_request_newsgroup_creation complete_newsgroup_creation_request
      webstump_admin_screen admin_login_screen admin_add_newsgroup
      display_help updateUsers 
      )
  );
  foreach my $action ( sort( keys(%actions) ) ) {
    foreach my $user ( sort( keys(%requestForUser) ) ) {
      my $case  = $makeCase->( $action, $user );
      my $calls = {};
      my $mock  = Test::MockModule->new( 'main', no_auto => 1 )->mock(
        user_error => sub { $calls->{user_error}++; exit(0); },
        error      => sub { $calls->{error}++;      exit(0); },
        manageRejectionReasons => sub {
          my ($url, $user, $request, $newsgroup) = @_;
          $calls->{manageRejectionReasons}++;
          is_deeply($request, $case->{req}, "$case->{name} manageRejectionReasons called with request");
          my $expectuser = $case->{req}->{moderator};
          is($user, $users->{$expectuser}, "$case->{name} manageRejectionReasons called with user");
          return 0;
        },
        map {
          my $f = $_;
          ( $f => sub { $calls->{$f}++ } )
        } @mocklist
      );
      my $mock2 = Test::MockModule->new( 'Webstump::User', no_auto => 1 )->mock(
        readUsersFromFile => sub { $calls->{readUsersFromFile}++; return $users; },
        updateUsers       => sub { $calls->{updateUsers}++; }
      );
      my $r = test_processWebRequest_run( $case->{req} );
      foreach my $output (qw(stdout stderr exit die)) {
        check( $r->{trap}, $case, $output );
      }
      check( $r, $case, 'wslog' );
      is_deeply( $calls, $case->{calls}, qq{$case->{name} makes expected calls} )
        or diag( explain($calls) );
    }
  }
}

sub check {
  my ( $got, $case, $output ) = @_;
  if ( defined( $case->{$output} ) ) {
    foreach my $test ( @{ $case->{$output} } ) {
      like( $got->{$output}, $test->{re}, "$case->{name} $test->{case}" );
    }
  } else {
    is( $got->{$output}, $case->{$output}, "$case->{name} no $output" );
  }
}

sub test_processWebRequest_run {
  my ($req) = @_;
  our $trap;
  local $trap;
  our %request;

  # processWebRequest is always called with $html_mode set.
  # This affects the error reporting.
  our $html_mode;
  local $html_mode = "yes";

  # global variables used in functions that cannot be mocked out
  our $base_address_for_files;
  local $base_address_for_files = "/relpath";
  our $supporter;
  local $supporter = 'somebody\@example.com';
  local *LOG;
  my $wslog;
  open( LOG, '>', \$wslog );
  local %request = %$req;
  trap { processWebRequest() };
  close LOG;
  return { trap => $trap, wslog => $wslog };
}
