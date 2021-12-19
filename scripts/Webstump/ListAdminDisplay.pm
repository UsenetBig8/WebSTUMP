#
# Copyright 1999 Igor Chudov
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
package Webstump::ListAdminDisplay;

# Display functions for managing moderation related options

use strict;
use warnings;
use Exporter 5.57 'import';

our $VERSION   = '1.00';
our @EXPORT_OK = qw(listManagementForm manageRejectionReasons);

use HTML::Escape qw/escape_html/;
use Webstump::Display qw(credentials exitButtons);
use Webstump::ListAdmin qw(listsInOrder getListLabel
  getRejectionMessage
  getRejectionReasons deleteRejectionReason updateRejectionReason
);
use Webstump::User qw(isListAdmin userData);

sub listManagementForm {
  my ( $url, $newsgroup, $user ) = @_;

  # Show the form only if user has list admin rights
  return 0 if !isListAdmin($user);

  my $hurl = escape_html($url);

  # Config list form
  print qq{<form method="post" action="$hurl">\n};
  print qq{<input name="action" value="edit_list" type="hidden">\n};
  credentials( $newsgroup, $user );
  print qq{<label>Configuration List: <select name="list_to_edit">\n};
  foreach my $list ( listsInOrder() ) {
    printf qq{<option value="%s">%s</option>\n}, $list, getListLabel($list);
  }
  print qq{</select></label>\n};
  print qq{<input type="submit" value="Edit">};
  main::link_to_help( "filter-lists", "filtering lists" );
  print qq{</form>\n};

  print qq{<hr>\n};

  if ( rejectionReasonsForm( $url, $newsgroup, $user ) ) {
    print qq{<hr>\n};
  }

  # Bad Newsgroups header action form
  print qq{<form method="post" action="$hurl">\n};
  print qq{<input name="action" value="manage_bad_newsgroups_header" type="hidden">\n};
  credentials( $newsgroup, $user );
  print qq{<input type="submit" value="Manage bad Newsgroups header action">};
  print qq{</form>\n};
  return 1;
}

sub manageRejectionReasons {
  my ( $url, $user, $request, $newsgroup ) = @_;
  return 1 if !isListAdmin($user);
  if ( my $deleteReason = $request->{deleteReason} ) {
    deleteRejectionReason( $newsgroup, $deleteReason );
    return 1;
  } elsif ( my $editReason = $request->{editReason} ) {
    editRejectionReasonPage( $url, $user, $editReason, $newsgroup );
    return 0;
  } elsif ( my $updateReason = $request->{updateReason} ) {
    if ( my ($reason) = $updateReason =~ m{\A(\w+)\z} ) {
      updateRejectionReason( $newsgroup, $reason, $request );
    }
    return 1;
  }
  return 1;
}

sub rejectionReasonsForm {
  my ( $url, $newsgroup, $user ) = @_;

  # Show the form only if user has list admin rights
  return 0 if !isListAdmin($user);

  my $hurl    = escape_html($url);
  my $reasons = getRejectionReasons($newsgroup);
  print qq{<form action="$hurl" method="post">\n};
  print qq{<input name="action" value="manageRejectionReasons" type="hidden">\n};
  credentials( $newsgroup, $user );
  print qq{<table><caption>Manage rejection reasons</caption>\n};
  print qq{<tr>};
  print qq{<th></th>};
  print qq{<th>Reason</th>};
  print qq{<th>Short description</th>};
  print qq{<th></th>};
  print qq{</tr>\n};

  foreach my $id ( sort( keys(%$reasons) ) ) {
    my $hid = escape_html($id);
    print qq{<tr>};
    print qq{<td><button name="deleteReason" value="$hid">Delete $hid</button></td>};
    print qq{<td>$hid</td>};
    printf q{<td>%s</td>}, escape_html( $reasons->{$id} );

    # TODO _NOW distinguish between STUMP reasons and Webstump managed reasons
    print qq{<td><button name="editReason" value="$hid">Edit $hid</button></td>};
  }
  print qq{</tr>\n};

  print qq{</table>\n};
  print qq{</form>\n};
  
  # Add new reason form submits as if 'Edit' clicked for the new name
  print qq{<form action="$hurl" method="post">\n};
  print qq{<input name="action" value="manageRejectionReasons" type="hidden">\n};
  credentials( $newsgroup, $user );
  print qq{<label>New reason: <input type="text" name="editReason" value=""></label>};
  print qq{<button type="submit">Add</button>};
  print qq{</form>\n};
  return 1;
}

sub editRejectionReasonPage {
  my ( $url, $user, $reason, $newsgroup ) = @_;
  my $hurl        = escape_html($url);
  my $hreason     = escape_html($reason);
  my $reasons     = getRejectionReasons($newsgroup);
  my $description = $reasons->{$reason} // q{};
  my $hdesc       = escape_html($description);
  my $message     = getRejectionMessage($reason);
  my $hmessage    = escape_html($message);
  main::begin_html("Edit rejection reason $reason for $newsgroup");
  print <<"END";
  <p>Here you may edit the short description of the rejection reason as used in the
     moderation pages.</p>
  <p>You may also provide a message that will be sent to the poster if their article
     is rejected for this reason. If provided, it will be used in preference to any
     message provided by STUMP.</p>
END
  print qq{<form method="post" action="$hurl">};
  credentials( $newsgroup, $user );
  print qq{<input name="action" value="manageRejectionReasons" type="hidden">\n};
  print
qq{<p><label>$hreason description <input name="description" type="text" size="40" value="$hdesc"></label></p>};
  print qq{<label><p>Message:</p>\n};
  print qq{<div><textarea name="message" rows="10" cols="72">$hmessage</textarea></div></label>\n};
  print qq{<div><button type="submit" name="updateReason" value="$hreason">Update</button></div>\n};
  print qq{</form>\n};

  main::end_html( exitButtons( $url, userData(), 'admin', $newsgroup ) );
}

1;
