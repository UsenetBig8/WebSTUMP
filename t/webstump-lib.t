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
  our %moderators;
  local %moderators = (
    ADMIN => "ADMINPW",
    USER1 => "USER1PW"
  );
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
  );

  # result to expect if there are no expected calls for the action
  my %nocalls = (
    loggedout => {
      'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
      calls  => { user_error => 1 }
    },
    admin => {
      'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
      calls  => { read_moderators => 1, user_error => 1 }
    },
    gooduser => {
      wslog  => [ { re => qr{SECURITY_ALERT:}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s,            case => 'exit(0)' } ],
      calls => { read_moderators => 1, user_error => 1 }
    },
    baduser => {
      wslog =>
        [ { re => qr{SECURITY_ALERT: Authentication denied}, case => 'security alert in LOG' } ],
      'exit' => [ { re => qr{^0$}s, case => 'exit(0)' } ],
      calls  => { read_moderators => 1, user_error => 1 }
    },
  );

  # Map of actions to functions expected to be called for kind of user
  my %actions = (
    moderation_screen => {
      fullAdmin => { read_moderators => 1, html_newsgroup_management => 1 },
      moderator => { read_moderators => 1, html_moderation_screen    => 1 }
    },
    approval_decision => { moderator => { read_moderators => 1, approval_decision         => 1 } },
    moderate_article  => { moderator => { read_moderators => 1, html_moderate_article     => 1 } },
    management_screen => { fullAdmin => { read_moderators => 1, html_newsgroup_management => 1 } },
    edit_list         => { fullAdmin => { read_moderators => 1, edit_configuration_list   => 1 } },
    add_user =>
      { fullAdmin => { read_moderators => 1, add_user => 1, html_newsgroup_management => 1 } },
    set_config_list => {
      fullAdmin => { read_moderators => 1, set_config_list => 1, html_newsgroup_management => 1 }
    },
    manage_bad_newsgroups_header =>
      { fullAdmin => { read_moderators => 1, manage_bad_newsgroups_header => 1 } },
    manage_bad_newsgroups_header_set => {
      fullAdmin => {
        read_moderators                  => 1,
        manage_bad_newsgroups_header_set => 1,
        html_newsgroup_management        => 1
      }
    },
    manage_bad_newsgroups_header_cancel =>
      { fullAdmin => { read_moderators => 1, html_newsgroup_management => 1 } },
    delete_user =>
      { fullAdmin => { read_moderators => 1, delete_user => 1, html_newsgroup_management => 1 } },
    change_password => {
      fullAdmin => { read_moderators => 1, html_change_password => 1 },
      moderator => { read_moderators => 1, html_change_password => 1 }
    },
    validate_change_password => {
      fullAdmin => { read_moderators => 1, validate_change_password => 1 },
      moderator => { read_moderators => 1, validate_change_password => 1 }
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
  my @mocklist = (
    qw(
      read_moderators
      html_login_screen html_moderation_screen html_newsgroup_management
      add_user edit_configuration_list set_config_list manage_bad_newsgroups_header
      manage_bad_newsgroups_header_set delete_user approval_decision
      html_moderate_article html_change_password validate_change_password
      init_request_newsgroup_creation complete_newsgroup_creation_request
      webstump_admin_screen admin_login_screen admin_add_newsgroup
      display_help
      )
  );
  foreach my $action ( sort( keys(%actions) ) ) {
    foreach my $user ( sort( keys(%requestForUser) ) ) {
      my $case  = $makeCase->( $action, $user );
      my $calls = {};
      my $mock  = Test::MockModule->new( 'main', no_auto => 1 )->mock(
        user_error => sub { $calls->{user_error}++; exit(0); },
        error      => sub { $calls->{error}++;      exit(0); },
        map {
          my $f = $_;
          ( $f => sub { $calls->{$f}++ } )
        } @mocklist
      );
      my $r = test_processWebRequest_run( $case->{req} );
      foreach my $output (qw(stdout stderr exit die)) {
        check( $r->{trap}, $case, $output );
      }
      check( $r, $case, 'wslog' );
      is_deeply( $calls, $case->{calls}, qq{$case->{name} makes expected calls} );
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
