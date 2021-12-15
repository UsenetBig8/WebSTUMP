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
package Webstump::Display;

# Functions to output pieces of HTML that are used in various places

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(exitButtons credentials);

use HTML::Escape qw/escape_html/;
use Webstump::User qw(getRights isAdmin isModerator);

# Return the HTML for the appropriate set of exit buttons
my %contextLabels = (
  welcome     => { moderate => q{},             manage => q{},           out => q{Refresh} },
  login       => { moderate => q{},             manage => q{},           out => q{Back} },
  moderate    => { moderate => q{Article List}, manage => q{Management}, out => q{Logout} },
  articleList => { moderate => q{Refresh},      manage => q{Management}, out => q{Logout} },
  admin       => { moderate => q{Moderation},   manage => q{Management}, out => q{Logout} },
  siteAdmin   => { moderate => q{},             manage => q{},           out => q{Logout} },
  unknown     => { moderate => q{},             manage => q{},           out => q{} }
);

sub exitButtons {
  my ( $ref, $user, $context, $newsgroup ) = @_;
  my $html   = qq{<div class="exitButtons">\n};
  my $labels = $contextLabels{$context} || $contextLabels{unknown};

  $html .= button( $ref, $labels->{out} );
  if ( isModerator($user) ) {
    $html .= actionButton( $ref, $labels->{moderate}, 'moderation_screen', $user, $newsgroup );
  }
  if ( isAdmin($user) ) {
    $html .= actionButton( $ref, $labels->{manage}, 'management_screen', $user, $newsgroup );
  }
  $html .= qq{</div>};
  return $html;
}

sub button {
  my ( $ref, $text ) = @_;
  return q{} if !$text;
  my $href  = escape_html($ref);
  my $htext = escape_html($text);
  return <<"END";
<form action="$href" method="get">
  <button type="submit">$htext</button>
</form>
END
}

sub actionButton {
  my ( $ref, $text, $action, $user, $newsgroup ) = @_;
  return q{} if !$text;
  my $href       = escape_html($ref);
  my $htext      = escape_html($text);
  my $hnewsgroup = escape_html($newsgroup);
  my $haction    = escape_html($action);
  my $username   = escape_html( $user->{id} );
  my $password   = escape_html( $user->{pw} );
  return <<"END";
<form action="$href" method="post">
  <input name="newsgroup" value="$hnewsgroup" type="hidden">
  <input name="moderator" value="$username" type="hidden">
  <input name="password" value="$password" type="hidden">
  <input name="action" value="$haction" type="hidden">
  <button type="submit">$htext</button>
</form>
END
}

sub credentials {
  my ( $newsgroup, $user ) = @_;
  my $ng = escape_html($newsgroup);
  my $id = escape_html( $user->{id} );
  my $pw = escape_html( $user->{pw} );
  print qq{<input name="newsgroup" value="$ng" type="hidden">\n};
  print qq{<input name="moderator" value="$id" type="hidden">\n};
  print qq{<input name="password" value="$pw" type="hidden">\n};
}

1;

