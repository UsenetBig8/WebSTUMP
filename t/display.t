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
# Tests for the Webstump::Display module. Run like this:
# prove -I webstump/scripts webstump/t/display.t

use strict;
use warnings;

use Test::More;

# Run tests inside a function so that we can just 'return' if
# a failure means it is not worth doing more of the tests under that
# function.

sub tests {
  use_ok( "Webstump::Display", qw(exitButtons) ) || return;
  test_button();
  test_actionButton();
  test_exitButtons();
}

tests();
done_testing();

sub test_button {
  my @cases = (
    {
      case   => 'no text',
      url    => 'http://example.com/test',
      text   => q{},
      expect => [ { re => qr{^$}, check => 'empty string' } ]
    },
    {
      case   => 'text=Label',
      url    => 'http://example.com/test',
      text   => 'Label',
      expect => [
        { re => qr{<form.*action="http://example.com/test"}, check => 'action' },
        { re => qr{<button type="submit">Label</button>},    check => 'text' }
      ]
    },
    {
      case   => 'text=This&That',
      url    => 'http://example.com/test?x&y',
      text   => 'This&That',
      expect => [
        { re => qr{<form.*action="http://example.com/test\?x&amp;y"}, check => 'action escaped' },
        { re => qr{<button type="submit">This&amp;That</button>},     check => 'text escaped' }
      ]
    }

  );
  foreach my $case (@cases) {
    my $got = Webstump::Display::button( $case->{url}, $case->{text} );
    foreach my $expect ( @{ $case->{expect} } ) {
      like( $got, $expect->{re}, "$case->{case} $expect->{check}" );
    }
  }
}

sub test_actionButton {
  my @cases = (
    {
      case   => 'no text',
      url    => 'http://example.com/test',
      text   => q{},
      expect => [ { re => qr{^$}, check => 'empty string' } ]
    },
    {
      case   => 'text=Label',
      url    => 'http://example.com/test',
      text   => 'Action 1',
      action => 'action1',
      user   => { id => 'user1', pw => 'pw123' },
      group  => 'm.t.mod',
      expect => [
        { re => qr{<form.*action="http://example.com/test"},               check => 'form action' },
        { re => qr{<input name="newsgroup" value="m.t.mod" type="hidden"}, check => 'newsgroup' },
        { re => qr{<input name="moderator" value="user1" type="hidden"},   check => 'user' },
        { re => qr{<input name="password" value="pw123" type="hidden"},    check => 'password' },
        { re => qr{<input name="action" value="action1" type="hidden"}, check => 'input action' },
        { re => qr{<button type="submit">Action 1</button>},            check => 'text' }
      ]
    },
    {
      case   => 'text=This&That',
      url    => 'http://example.com/test?x&y',
      text   => 'This&That',
      action => 'action<1>',
      user   => { id => 'user>1', pw => 'pw&123' },
      group  => 'alt.bacon&eggs.m',
      expect => [
        { re => qr{<form.*action="http://example.com/test\?x&amp;y"}, check => 'action escaped' },
        {
          re    => qr{<input name="newsgroup" value="alt.bacon&amp;eggs.m" type="hidden"},
          check => 'newsgroup escaped'
        },
        {
          re    => qr{<input name="moderator" value="user&gt;1" type="hidden"},
          check => 'user escaped'
        },
        {
          re    => qr{<input name="password" value="pw&amp;123" type="hidden"},
          check => 'password escaped'
        },
        {
          re    => qr{<input name="action" value="action&lt;1&gt;" type="hidden"},
          check => 'input action escaped'
        },
        { re => qr{<button type="submit">This&amp;That</button>}, check => 'text escaped' }
      ]
    }

  );
  foreach my $case (@cases) {
    my $got = Webstump::Display::actionButton( map { $case->{$_} } qw(url text action user group) );
    foreach my $expect ( @{ $case->{expect} } ) {
      like( $got, $expect->{re}, "$case->{case} $expect->{check}" );
    }
  }

}

sub test_exitButtons {
  my %contextLabels = (
    welcome     => { moderate => q{},             manage => q{},           out => q{Refresh} },
    login       => { moderate => q{},             manage => q{},           out => q{Back} },
    moderate    => { moderate => q{Article List}, manage => q{Management}, out => q{Logout} },
    articleList => { moderate => q{Refresh},      manage => q{Management}, out => q{Logout} },
    admin       => { moderate => q{Moderation},   manage => q{Management}, out => q{Logout} },
    siteAdmin   => { moderate => q{},             manage => q{},           out => q{Logout} },
    unknown     => { moderate => q{},             manage => q{},           out => q{} }
  );
  my @cases = (
    {
      case    => 'welcome',
      url     => 'http://example.com/test',
      context => 'welcome',
      user    => { id => '', pw => '' },
      group   => 'm.t.mod',
      expect  => [
        { re => qr{\A\s*<div class="exitButtons".*</div>\s*\z}s, check => 'div wrapper' },
        { re => qr{\A(?!(?:.*<form){2,})}s,                      check => 'single form/button' },
        { re => qr{\A(?!.*<input)}s,                             check => 'no input' },
        { re => qr{<button type="submit">Refresh</button>},      check => 'button says Refresh' }
      ]
    },
    {
      case    => 'login',
      url     => 'http://example.com/test',
      context => 'login',
      user    => { id => '', pw => '' },
      group   => 'm.t.mod',
      expect  => [
        { re => qr{\A(?!(?:.*<form){2,})}s,              check => 'single form/button' },
        { re => qr{\A(?!.*<input)}s,                     check => 'no input' },
        { re => qr{<button type="submit">Back</button>}, check => 'button says Back' }
      ]
    },
    {
      case    => 'moderate',
      url     => 'http://example.com/test',
      context => 'moderate',
      user    => {
        id        => 'user',
        pw        => 'user123',
        fullAdmin => 0,
        moderate  => 1
      },
      group  => 'm.t.mod',
      expect => [
        { re => qr{\A(?!(?:.*<form){3,})(?:.*<form){2,2}}s, check => 'two forms/buttons' },
        {
          re    => qr{<input name="action" value="moderation_screen" type="hidden"},
          check => 'moderation_screen'
        },
        { re => qr{<button type="submit">Article List</button>}, check => 'Article List button' },
        { re => qr{<button type="submit">Logout</button>},       check => 'Logout button' }
      ]
    },
    {
      case    => 'article list',
      url     => 'http://example.com/test',
      context => 'articleList',
      user    => {
        id        => 'user',
        pw        => 'user123',
        fullAdmin => 0,
        moderate  => 1
      },
      group  => 'm.t.mod',
      expect => [
        { re => qr{\A(?!(?:.*<form){3,})(?:.*<form){2,2}}s, check => 'two forms/buttons' },
        {
          re    => qr{<input name="action" value="moderation_screen" type="hidden"},
          check => 'moderation_screen'
        },
        { re => qr{<button type="submit">Refresh</button>}, check => 'Refresh button' },
        { re => qr{<button type="submit">Logout</button>},  check => 'Logout button' }
      ]
    },
    {
      case    => 'admin',
      url     => 'http://example.com/test',
      context => 'admin',
      user    => {
        id        => 'admin',
        pw        => 'admin123',
        fullAdmin => 1,
        moderate  => 0
      },
      group  => 'm.t.mod',
      expect => [
        { re => qr{\A(?!(?:.*<form){3,})(?:.*<form){2,2}}s, check => 'two forms/buttons' },
        {
          re    => qr{<input name="action" value="management_screen" type="hidden"},
          check => 'management_screen'
        },
        { re => qr{<button type="submit">Management</button>}, check => 'Management button' },
        { re => qr{<button type="submit">Logout</button>},     check => 'Logout button' }
      ]
    },
    {
      case    => 'site admin',
      url     => 'http://example.com/test',
      context => 'siteAdmin',
      user    => { id => '', pw => 'site123' },
      group   => 'm.t.mod',
      expect  => [
        { re => qr{\A\s*<div class="exitButtons".*</div>\s*\z}s, check => 'div wrapper' },
        { re => qr{\A(?!(?:.*<form){2,})}s,                      check => 'single form/button' },
        { re => qr{\A(?!.*<input)}s,                             check => 'no input' },
        { re => qr{<button type="submit">Logout</button>},       check => 'button says Logout' }
      ]
    },
    {
      case    => 'unknown',
      url     => 'http://example.com/test',
      context => 'unknown',
      user    => { id => 'maybe', pw => 'pw123' },
      group   => 'm.t.mod',
      expect  => [
        { re => qr{\A\s*<div class="exitButtons".*</div>\s*\z}s, check => 'div wrapper' },
        { re => qr{\A(?!.*<form)}s,                              check => 'no form/button' },
      ]
    }
  );
  foreach my $case (@cases) {
    my $got = exitButtons( map { $case->{$_} } qw(url user context group) );
    foreach my $expect ( @{ $case->{expect} } ) {
      like( $got, $expect->{re}, "$case->{case} $expect->{check}" );
    }
  }

}
