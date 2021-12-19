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
# Tests for the Webstump::ListAdminDisplay module. Run like this:
# prove -I webstump/scripts webstump/t/listAdminDisplay.t

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Trap;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok( "Webstump::ListAdminDisplay", qw(listManagementForm manageRejectionReasons) ) || return;
  test_listManagementForm();
  test_manageRejectionReasons();
}

tests();
done_testing();

sub test_listManagementForm {
  my $test      = 'listManagementForm';
  my $newsgroup = "m.t.m";
  my $url       = "http://example.com/";
  my @cases     = (
    {
      case  => 'notListAdmin',
      user  => {},
      check => [ { check => 'no output', re => qr{\A\z} } ]
    },
    {
      case  => 'listAdmin',
      user  => { listAdmin => 1 },
      check => [
        {
          check => 'edit_list form',
          re    => qr{<input name="action" value="edit_list" type="hidden">}
        },
        {
          check => 'select list_to_edit',
          re    => qr{<label>Configuration List: <select name="list_to_edit">}
        },
        {
          check => 'option good.posters.list',
          re    => qr{<option value="good.posters.list">}
        },
        {
          check => 'bad_newsgroups form',
          re    => qr{<input name="action" value="manage_bad_newsgroups_header" type="hidden">}
        },
        {
          check => 'rejection reasons form',
          re    => qr{<input name="action" value="manageRejectionReasons" type="hidden">}
        },
        {
          check => 'delete rejection reason button',
          re =>
            qr{<td><button name="deleteReason" value="somereason">Delete somereason</button></td>}
        },
        {
          check => 'edit rejection reason button',
          re => qr{<td><button name="editReason" value="somereason">Edit somereason</button></td>}
        },
      ],
      reasons => { somereason   => "Some rejection reson" },
      calls   => { link_to_help => 1, getRejectionReasons => 1 }
    }
  );
  foreach my $case (@cases) {
    my $testcase = "$test $case->{case}";
    my $reasons  = $case->{reasons} // {};
    my $calls    = {};
    my $mock     = Test::MockModule->new( 'main', no_auto => 1 )
      ->mock( link_to_help => sub { $calls->{link_to_help}++; }, );
    my $mockLA = Test::MockModule->new( 'Webstump::ListAdminDisplay', no_auto => 1 )
      ->mock( getRejectionReasons => sub { $calls->{getRejectionReasons}++; return $reasons; } );
    trap { listManagementForm( $url, $newsgroup, $case->{user} ) };
    $trap->did_return(qq{$testcase normal return});
    my $got = $trap->{stdout};

    foreach my $check ( @{ $case->{check} } ) {
      like( $got, $check->{re}, qq{$testcase $check->{check}} );
    }
    is_deeply( $calls, $case->{calls} // {}, qq{$testcase makes expected calls} )
      or diag( explain($calls) );
  }
}

sub test_manageRejectionReasons {
  my $test      = 'manageRejectionReasons';
  my $newsgroup = "m.t.m";
  my $url       = "http://example.com/";
  my %la        = ( user => { listAdmin => 1 } );
  my @cases     = (
    { case => 'not listAdmin', user => {}, calls => {}, r => 1, request => {} },
    {
      case => 'delete reason',
      %la,
      calls   => { deleteRejectionReason => 1 },
      r       => 1,
      request => { deleteReason => 'test' }
    },
    {
      case => 'edit reason',
      %la,
      calls   => { editRejectionReasonPage => 1 },
      r       => 0,
      request => { editReason => 'test' }
    },
    {
      case => 'update reason',
      %la,
      calls   => { updateRejectionReason => 1 },
      r       => 1,
      request => { updateReason => 'test' }
    }
  );
  foreach my $case (@cases) {
    my $testcase = "$test $case->{case}";
    my $reasons  = $case->{reasons} // {};
    my $calls    = {};
    my @mocklist = (qw(deleteRejectionReason editRejectionReasonPage updateRejectionReason));
    my $mockLA   = Test::MockModule->new( 'Webstump::ListAdminDisplay', no_auto => 1 );
    foreach my $fn (@mocklist) {
      $mockLA->mock( $fn => sub { $calls->{$fn}++; } );
    }

    my $r = trap { manageRejectionReasons( $url, $case->{user}, $case->{request}, $newsgroup ) };
    $trap->did_return(qq{$testcase normal return});
    $trap->quiet(qq{$testcase no output});
    is( $r, $case->{r}, "$testcase return expected value" );
    is_deeply( $calls, $case->{calls} // {}, qq{$testcase makes expected calls} )
      or diag( explain($calls) );
  }

}
