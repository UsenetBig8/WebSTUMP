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
# Tests for the Webstump::ListAdmin module. Run like this:
# prove -I webstump/scripts webstump/t/listAdmin.t

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok(
    "Webstump::ListAdmin", qw(
      listsInOrder getListLabel getRejectionReasons decisionForSTUMP
      deleteRejectionReason updateRejectionReason
      )
  ) || return;
  test_listsInOrder();
  test_getListLabel();
  test_getRejectionReasons();
  test_decisionForSTUMP();
  test_saveRejectionReasons();
  test_deleteRejectionReason();
  test_updateRejectionReason();
}

tests();
done_testing();

sub test_listsInOrder {
  my $expect = [
    'good.posters.list',   'watch.posters.list', 'bad.posters.list', 'good.subjects.list',
    'watch.subjects.list', 'bad.subjects.list',  'watch.words.list', 'bad.words.list'
  ];
  my @lists = listsInOrder();
  is_deeply( [@lists], $expect, "listsInOrder in order" )
    or diag( explain( [@lists] ) );
}

sub test_getListLabel {
  my @cases = (
    { list => 'good.posters.list', label => "Good Posters List" },
    { list => 'no.such.list',      label => "" },
  );
  foreach my $case (@cases) {
    is( getListLabel( $case->{list} ), $case->{label}, qq{$case->{list} label "$case->{label}"} );
  }
}

sub test_getRejectionReasons {
  my $case        = 'getRejectionReasons';
  my $newsgroup   = 'm.t.m';
  my ($test_home) = $0 =~ m{^(.*)/listAdmin\.t$};
  ok( -d "$test_home/data/config/", qq{$case found test data} ) || return;

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");

  # declare these variables separately to avoid the used once warning
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = qq{$test_home/data};
  %main::request       = ( newsgroup => $newsgroup );
  my $expect = {
    offtopic  => "Message is grossly off topic (spam, turks, etc)",
    crosspost => "Inappropriate crossposting",
    charter   => "Technical violation of charter (binary, exc. quoting)",
    harassing => "Message of harassing/insulting/hatemongering content",
    ignore    => "Reject without notifying sender (spam, etc)",
    test      => "Reject reason used in tests"
  };
  my $reasons = getRejectionReasons($newsgroup);
  is_deeply( $reasons, $expect, qq{$case returned expected data} );
}

sub test_decisionForSTUMP() {
  my $test        = 'decisionForSTUMP';
  my $newsgroup   = 'm.t.m';
  my ($test_home) = $0 =~ m{^(.*)/listAdmin\.t$};
  ok( -d "$test_home/data/config/", qq{$test found test data} ) || return;

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");

  # declare these variables separately to avoid the used once warning
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = qq{$test_home/data};
  %main::request       = ( newsgroup => $newsgroup );
  my $shortComment = "Moderator comment that is short";
  my $longComment  = "Moderator comment that is long enough to need to"
    . " be wrapped to 72 characters in the message";
  my $longCommentWrapped = "Moderator comment that is long enough to"
    . " need to be wrapped to 72\ncharacters in the message";

  # This must match the contents of the reject-test.txt file
  my $testMessageWrapped =
      "This is a test of the Webstump managed rejection messages. If the 'test'\n"
    . "reason is selected then this message should be included in the mail to\n"
    . "be sent rather than sending the 'test' reason to STUMP.\n" . "\n"
    . "This also tests the wrapping of this message in the email. The text will\n"
    . "be soft-wrapped in the textarea (at least by my browser) which makes it\n"
    . "easier to write paragraphs but when sending the email it should be\n"
    . "wrapped to 72 columns.\n" . "\n"
    . "Signed, Moderators";
  my @cases = (
    { case => 'approve no comment', decision => 'approve', expect => "\napprove\n" },
    {
      case     => 'approve short comment',
      decision => 'approve',
      comment  => $shortComment,
      expect   => "\napprove\ncomment $shortComment\n"
    },
    {
      case     => 'approve long comment',
      decision => 'approve',
      comment  => $longComment,
      expect   => "\napprove\ncomment $longCommentWrapped\n"
    },
    {
      case     => 'reject charter no comment',
      decision => 'reject charter',
      expect   => "\nreject charter\n"
    },
    {
      case     => 'reject charter short comment',
      decision => 'reject charter',
      comment  => $shortComment,
      expect   => "\nreject charter\ncomment $shortComment\n"
    },
    {
      case     => 'reject charter long comment',
      decision => 'reject charter',
      comment  => $longComment,
      expect   => "\nreject charter\ncomment $longCommentWrapped\n"
    },
    {
      case     => 'reject test no comment',
      decision => 'reject test',
      expect   => "\nreject custom\ncomment $testMessageWrapped\n"
    },
    {
      case     => 'reject test short comment',
      decision => 'reject test',
      comment  => $shortComment,
      expect   => "\nreject custom\ncomment $shortComment\n\n$testMessageWrapped\n"
    },
    {
      case     => 'reject test long comment',
      decision => 'reject test',
      comment  => $longComment,
      expect   => "\nreject custom\ncomment $longCommentWrapped\n\n$testMessageWrapped\n"
    },
  );
  foreach my $case (@cases) {
    my $testcase = "$test $case->{case}";
    my $message  = decisionForSTUMP( $case->{decision}, $case->{comment} );
    is( $message, $case->{expect}, "$testcase message" );
  }
}

# make getRejectionReasons read the file again
# which may be a temp file created in a test
sub resetReasons {
  my ($newsgroup) = @_;
  my $reasons = getRejectionReasons($newsgroup);
  foreach my $key ( keys(%$reasons) ) {
    delete $reasons->{$key};
  }
}

# Tests that write to files may need to start with a copy of test data
sub readFile {
  my ($file) = @_;
  open( my $in, '<', "$file" ) || die "open < $file $!";
  my $data = do { local $/; <$in> };
  close($in);
  return $data;
}

sub copyToTempdir {
  my ( $dir, @files ) = @_;
  my $tempdir = tempdir( CLEANUP => 1 );
  foreach my $file (@files) {

    # if $file is a path create the directories
    if ( my ( $dir, $f ) = $file =~ m{\A(.*)/([^/]*)\z} ) {
      my @dirs = make_path("$tempdir/$dir");
      if ( !scalar(@dirs) ) { die "failed to create $dir $!" }
    }

    # If $file ends with '/' just create the directories
    if ( -f "$dir/$file" ) {
      my $data = readFile("$dir/$file");
      open( my $out, '>', "$tempdir/$file" ) || die "open > $tempdir/$file $!";
      print $out $data;
      close $out;
    }
  }
  return $tempdir;
}

sub test_saveRejectionReasons {
  my $case        = 'saveRejectionReasons';
  my $newsgroup   = 'm.t.m';
  my ($test_home) = $0 =~ m{^(.*)/listAdmin\.t$};
  ok( -d "$test_home/data/config/", qq{$case found test data} ) || return;

  resetReasons($newsgroup);

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");
  my $configdir = "config/newsgroups/$newsgroup/";
  my $testdir   = copyToTempdir( qq{$test_home/data}, $configdir );

  # declare these variables separately to avoid the used once warning
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = qq{$testdir};
  %main::request       = ( newsgroup => $newsgroup );
  my $reasons = { test => "Testing $case" };
  my $expect  = "test::Testing $case\n";
  do {
    my $mock = Test::MockModule->new( 'Webstump::ListAdmin', no_auto => 1 );
    $mock->mock( getRejectionReasons => sub { return $reasons } );

    # not exported so use the full name
    Webstump::ListAdmin::saveRejectionReasons($newsgroup);
  };

  my $got = readFile("$testdir/$configdir/rejection-reasons");
  is( $got, $expect, "$case saved" );
  my $gotReasons = getRejectionReasons($newsgroup);
  is_deeply( $gotReasons, $reasons, "$case read back saved reasons" );
}

sub test_deleteRejectionReason {
  my $case        = 'deleteRejectionReason';
  my $newsgroup   = 'm.t.m';
  my ($test_home) = $0 =~ m{^(.*)/listAdmin\.t$};
  ok( -d "$test_home/data/config/", qq{$case found test data} ) || return;

  resetReasons($newsgroup);

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");
  my $configdir = "config/newsgroups/$newsgroup/";
  my $testMessage = "$configdir/messages/reject-test.txt";
  my $testdir =
    copyToTempdir( qq{$test_home/data}, "$configdir/rejection-reasons", $testMessage );

  # declare these variables separately to avoid the used once warning
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = qq{$testdir};
  %main::request       = ( newsgroup => $newsgroup );
  my $expect = {
    offtopic  => "Message is grossly off topic (spam, turks, etc)",
    crosspost => "Inappropriate crossposting",
    charter   => "Technical violation of charter (binary, exc. quoting)",
    harassing => "Message of harassing/insulting/hatemongering content",
    ignore    => "Reject without notifying sender (spam, etc)",
  };
  ok(-f "$testdir/$testMessage", "$case reject message present before delete");
  deleteRejectionReason( $newsgroup, 'test' );

  my $got = getRejectionReasons($newsgroup);
  is_deeply( $got, $expect, "$case getRejectionReasons" );
  resetReasons($newsgroup);
  my $gotReset = getRejectionReasons($newsgroup);
  is_deeply( $gotReset, $expect, "$case getRejectionReasons after reset" );
  ok(!-f "$testdir/$testMessage", "$case reject message not present after delete");
}

sub test_updateRejectionReason {
  my $case        = 'updateRejectionReason';
  my $newsgroup   = 'm.t.m';
  my ($test_home) = $0 =~ m{^(.*)/listAdmin\.t$};
  ok( -d "$test_home/data/config/", qq{$case found test data} ) || return;

  resetReasons($newsgroup);

  # Checking the navigation to the file means we need to...
  require_ok("webstump.lib.pl");
  my $configdir = "config/newsgroups/$newsgroup/";
  my $testMessage = "$configdir/messages/reject-extra.txt";
  my $testdir =
    copyToTempdir( qq{$test_home/data}, "$configdir/rejection-reasons" );

  # declare these variables separately to avoid the used once warning
  local ( $main::webstump_home, %main::request );
  $main::webstump_home = qq{$testdir};
  %main::request       = (newsgroup => $newsgroup );
  my $request = {
    description => "Reason added by update test",
    message => "Rejection message for 'extra'"
  };
  my $expect = {
    offtopic  => "Message is grossly off topic (spam, turks, etc)",
    crosspost => "Inappropriate crossposting",
    charter   => "Technical violation of charter (binary, exc. quoting)",
    harassing => "Message of harassing/insulting/hatemongering content",
    ignore    => "Reject without notifying sender (spam, etc)",
    test      => "Reject reason used in tests",
    extra     => "Reason added by update test"
  };
  ok(!-f "$testdir/$testMessage", "$case reject message not present before update");
  updateRejectionReason( $newsgroup, 'extra', $request );

  my $got = getRejectionReasons($newsgroup);
  is_deeply( $got, $expect, "$case getRejectionReasons" );
  resetReasons($newsgroup);
  my $gotReset = getRejectionReasons($newsgroup);
  is_deeply( $gotReset, $expect, "$case getRejectionReasons after reset" );
  ok(-f "$testdir/$testMessage", "$case reject message present after update");
}
