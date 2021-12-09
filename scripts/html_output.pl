#!/usr/bin/env perl
#
# Copyright 1999 Igor Chudov
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
# This is a module with functions for HTML output.
#
# I separate it from the main STUMP stuff because these functions are
# bulky and not very interesting.
#
#
use strict;
use warnings;
use HTML::Escape qw/escape_html/;
use Webstump::Display qw(exitButtons);
use Webstump::User qw(userData);

# Declare the global variables
our $base_address;
our $base_address_for_files;
our %moderators;
our @newsgroups_array;
our %newsgroups_index;
our $queues_dir;
our %rejection_reasons;
our %request;
our $request_method;
our @short_rejection_reasons;
our $STUMP_URL;
our $webstump_config;
our $webstump_home;

sub begin_html {
  my $title = pop( @_ );
  print <<"END";
Content-Type: text/html

<html>
<head>
<meta charset="UTF-8">
<TITLE>$title</TITLE>
<style>
  .modcomment label,textarea { vertical-align: middle; }
  span.hline:after,span.hline:before {
    content:'\\A0\\A0\\A0\\A0\\A0\\A0';
    text-decoration:line-through;
  }
  span.hline { font: small-caption; }
  span.warning { color: red; }
  div.exitButtons form { display: inline; }
</style>
</head>
<BODY BGCOLOR="#C5C5FF" BACKGROUND=$base_address_for_files/images/bg1.jpg>
<H1>$title</H1>

END
  if( &is_demo_mode ) {
    print "<B> You are operating in demonstration mode. User actions will have no effect.</B><HR>\n";
  }
  
}


sub end_html {
  my ($footer) = @_;
  $footer //= q{};
  print "\n<HR>Thank you for using <A HREF=$STUMP_URL>STUMP Robomoderator</A>.
  $footer
</body>
</html>
";
}

# prints a link to help
# accepts topic id and topic name.
#
sub link_to_help {
  my $topic_name = pop( @_ );
  my $topic = pop( @_ );

  #&print_image( "help.gif", "" );

  print "<A HREF=$base_address?action=help&topic=$topic TARGET=new>Click here for help on $topic_name</A>\n";
}

#
# prints image and an alt text
#
sub print_image { # image_file, alt_text
  my $alt = pop( @_ );
  my $file = pop( @_ );

  print "<IMG SRC=$base_address_for_files/images/$file ALT=\"$alt\" ALIGN=BOTTOMP>\n";
}

# prints the welcome page and login screen.
sub html_welcome_page {
  &begin_html( "Welcome to WebSTUMP" );

  print 

"Welcome to WebSTUMP, the moderators' front end for <A
HREF=http://www.algebra.com/~ichudov/stump>STUMP</A> users -- USENET newsgroup
moderators. Only authorized users are allowed to log into this
program.

<HR>";

  my $motd_file = "$webstump_home/config/motd";

  if( -f $motd_file && -r $motd_file ){
    open( MOTD, $motd_file );
    print "<B>Message of the Day:</B><BR><PRE>\n";
    print while( <MOTD> );
    close( MOTD );
    print "</PRE><HR>\n";
  }

  print "
Newsgroups Status:<BR>
<TABLE BORDER=3>\n";

  for( sort @newsgroups_array ) {
    print "<TR><TD>";
    
    my $count = &get_article_count( $_ );

    print " <A HREF=$base_address?action=login_screen\&newsgroup=$_>$_</A>";
    &print_image( "smiley.gif", "" ) if $count;
    print "</TD>";


    print "<TD>$count messages in queue<BR></TD>";
    print "<TD><A HREF=$base_address?action=init_request_newsgroup_creation\&newsgroup=$_>Request creation</A></TD>\n";
  }

  print "</TABLE>\n";
  print "<HR>Note: click on the newsgroup to login in as moderator. 
Click on 'Request Creation' to ask a sysadmin at a specific domain 
to carry your newsgroup.\n<HR>
<A HREF=$base_address?action=admin_login>Click here to administer this WebSTUMP installation</A>
";
  end_html(exitButtons($base_address, userData(), 'welcome'));
}

# prints the login screen for newsgroup.
sub html_login_screen {
  my $newsgroup = $request{'newsgroup'} || &error( "newsgroup not defined" );

  my $count = &get_article_count( $newsgroup );


  if( $count ) {
    &begin_html( "$count articles in queue for $newsgroup" );
  } else {
    &begin_html( "Empty Queue for $newsgroup" );
  }

  print
" Welcome to the Moderation  Center for  $newsgroup. Please bookmark
this page. <HR>";

  my $color     = "";
  my $end_color = "";

  if( $count ) {
    $color = "<font color=red>";
    $end_color = "<font color=black>";
  }

  print 
"<FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=moderation_screen TYPE=hidden>
  $color ($count ";
  
  &print_image( "new_tiny2.gif", "new" ) if $count;

  print " articles available)<BR> $end_color
 Login: <INPUT NAME=moderator VALUE=\"\" SIZE=20>
 <BR>
 Password: <INPUT NAME=password TYPE=password VALUE=\"\" SIZE=20>
 <BR>
 <INPUT TYPE=submit VALUE=\"Proceed with Login\">
 <INPUT TYPE=reset VALUE=\"Reset\">
 <INPUT NAME=newsgroup VALUE=\"$newsgroup\" TYPE=hidden>
 </FORM><HR>
  Please log into $newsgroup. You can only log in if you know your login id
  and know the secret password. You should not give your password to any
  unauthorized user. Your login id and password are NOT case sentitive, 
  which means that,
  for example, \"xyzzy\" and \"XyZZY\" are equally valid.<P>
";

  print "
 Log in as \"admin\" if you want to 
<UL>
  <LI> edit filtering lists.";

  &link_to_help( "filter-lists", "Filter Lists" );

  print "
  <LI> add/delete users or change their passwords.
  <LI> First Time Users: You have to log in as admin and add a moderator user
  who will be able to moderate the newsgroup. Then log in again as that
  user. If you are a new user, you have to have your admin password assigned to
  you by the administrator.
</UL>

";
  end_html(exitButtons($base_address, userData(), 'login'));
}

# prints the login screen for newsgroup.
sub admin_login_screen {
  &begin_html( "Administrative login" );

  print
"
Attention: this page is only for the maintainer of the whole WebSTUMP
installation. Please return to the main page if you are not the maintainer
of this installation. <HR>
";

  print 
"<FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=webstump_admin_screen TYPE=hidden>
 Password: <INPUT NAME=password TYPE=password VALUE=\"\" SIZE=20>
 <BR>
 <INPUT TYPE=submit VALUE=\"Proceed with Login\">
 <INPUT TYPE=reset VALUE=\"Reset\">
 </FORM>
";

  end_html(exitButtons($base_address, userData(), 'login'));
}

sub display_article {
  my ($newsgroup, $file, $class, $limit) = @_;
  my ($dir) = getQueueDir($newsgroup) =~ m{^(.+)$};
  my $articleDir = "$dir/$file";
  my $linkbase = "$base_address_for_files/queues/$newsgroup/$file";
  my $partsList = "$articleDir/text.files.lst";
  my $lineCount = defined($limit) ? $limit : 1;
  my $inc = defined($limit) ? 1 : 0;
  # TODO make this configurable via options in a web form
  my $prefix = $class eq 'multi' ? sub {
    my ($line) = @_;
    chomp $line;
    return substr(q{>>>>>>  } . $line, 0, 75) . "\n";
  } : sub {
     return @_;
  };

  if ( -d "$articleDir" && open( my $partsFH, "<", "$partsList" ) ) {
    my @attachments = ();
    print "<HR>\n" if &print_article_warning( $newsgroup, $file );

    while ( my $part = <$partsFH> ) {
      my ( $filename, $type, $disposition ) = $part =~ m{^(\S+)\s+(\S+)\s+(\S+)$};
      if ($disposition eq 'attachment') {
        push @attachments, { filename => $filename, type => $type };
        next;
      }
      if ( $type eq "text/plain" && $lineCount > 0 ) {
        print qq{<PRE class="$class">\n};
        open( my $FH, "$articleDir/$filename" );
        while (my $line = <$FH>) {
          print escape_html($prefix->($line));
          last if ($lineCount -= $inc) <= 0;
        }
        close($FH);
        print "\n</PRE>\n\n";
      } else {
        print qq{<div><span class="hline">$type $filename</span></div>};
        print qq{<div>\n};
        inline_image($linkbase, $filename, $type);
        print qq{</div>\n};
        }
      }
    close($partsFH);
    foreach my $a (@attachments) {
      my $afile = $a->{filename};
      my $link = "$linkbase/$afile";
      my $type = $a->{type};
      print(qq{<p>Attachment <a href="$link">$afile</a> $a->{type}</p>\n});
    }
  } else {
    print "This message ($articleDir) no longer exists -- maybe it was " .
          "approved or rejected by another moderator.";
  }
}
# single article moderation page
sub html_moderate_article {
  my ($newsgroup) = required_parameter('newsgroup') =~ m{^([\w.]+)$};
  my $moderator = $request{'moderator'};
  my $password = $request{'password'};
  my ($file)      = ( shift @_ || &required_parameter('file') ) =~ m{^(\w+)$};

  &begin_html( "Main Moderation Screen: $newsgroup" );
  print "<HR>\n";

  &read_rejection_reasons;

  my $headers =article_file_name( $newsgroup, $file ) . "/headers.txt";

  print qq{<PRE class="single header">\n};
  open( my $FH, "$headers" );
  while (my $line = <$FH>) {
    print escape_html($line);
  }
  close($FH);
  print "\n</PRE>\n\n";

  display_article($newsgroup, $file, "single");

      print "<HR>
<FORM NAME=decision METHOD=$request_method action=$base_address>
";

  print "
<INPUT NAME=action VALUE=approval_decision TYPE=hidden>";
  &html_print_credentials;
  print "<SELECT NAME=\"decision_$file\">
<OPTION VALUE=\"approve\">Approve</OPTION>
";

      foreach (sort(keys %rejection_reasons)) {
        print "<OPTION VALUE=\"reject $_\">Reject -- $rejection_reasons{$_}</OPTION>\n";
      }

      print "</SELECT>\n";

      print qq{<div class="modcomment">\n};
      print qq{<label for="modcomment">Comment:</label>\n};
      print qq{<textarea  id="modcomment" name="comment" rows="5" cols="72"></textarea>\n};
      print qq{</div>\n};

  print "<BR>
<INPUT TYPE=radio NAME=poster_decision VALUE=nothing CHECKED>Don't change poster's status</INPUT>
<INPUT TYPE=radio NAME=poster_decision VALUE=preapprove 
>Preapprove poster</INPUT>
<INPUT TYPE=radio NAME=poster_decision VALUE=ban 
  ONCLICK=\"alert( 'Banning a poster is a controversial practice'); \"
> Ban All Posts by this Person (Careful!)</INPUT>
<BR><BR>
<INPUT TYPE=radio NAME=thread_decision VALUE=nothing CHECKED>Don't change thread's status</INPUT>
<INPUT TYPE=radio NAME=thread_decision VALUE=preapprove>Preapprove thread, by Subject:</INPUT>
<BR>

<INPUT TYPE=radio NAME=thread_decision VALUE=ban
  ONCLICK=\"alert( 'Banning a thread is a controversial practice'); \"
>Ban Entire Thread By Subject (Careful!)</INPUT>
<INPUT TYPE=radio NAME=thread_decision VALUE=watch>Put Entire thread on a Watch, by Subject:</INPUT>

<BR><BR>
<I>
NOTE: Decisions to ban and preapprove posters and threads can be reversed by 
logging in as \"admin\" and editing respective lists of preapproved
and banned threads  and posters.
";

  &link_to_help( "filter-lists", "automatic filtering and filter lists, blacklisting and preapproved threads." );

  print "Be really careful about blacklisting of everyone except spammers.</I><BR><BR>

<INPUT TYPE=radio NAME=next_screen VALUE=single CHECKED> 
	Review ONE article in next screen
<INPUT TYPE=radio NAME=next_screen VALUE=multiple> 
	Review multiple articles in next screen
<HR>

<INPUT TYPE=submit VALUE=\"Submit\">
<INPUT TYPE=reset VALUE=\"Reset\">
";

      print "</FORM>\n\n";
  print "<BR><A HREF=$base_address?action=change_password&newsgroup=$newsgroup&" .
        "moderator=$moderator&password=$password>Change Password</A>";

  closedir( QUEUE );
  end_html(exitButtons($base_address, userData(), 'moderate', $newsgroup));
}

# WebSTUMP administrative screen
sub webstump_admin_screen {

  &verify_admin_password;

  my $password = $request{'password'};

  &begin_html( "WebSTUMP Administration" );
  print "
<FORM METHOD=$request_method action=$base_address>
<INPUT NAME=action VALUE=admin_add_newsgroup TYPE=hidden>
<INPUT NAME=password VALUE=\"$password\" TYPE=hidden>\n";


  print "
<HR>
Create a new newsgroup on the server:<BR>

Newsgroup:<BR> <INPUT NAME=newsgroup_name VALUE=\"\" SIZE=50><BR>
Address to send approved/rejected messages <BR>
	<INPUT NAME=newsgroup_approved_address VALUE=\"\" SIZE=30><BR>
Admin Password For this group:<BR> <INPUT NAME=newsgroup_password VALUE=\"\" SIZE=10><BR>
<INPUT TYPE=submit VALUE=\"Submit\">
<INPUT TYPE=reset VALUE=\"Reset\"><HR>
";

      print "</FORM>\n\n<PRE>\n";

  end_html(exitButtons($base_address, userData(), 'siteAdmin'));
}

# WebSTUMP "add newsgroup" function
sub admin_add_newsgroup {

  &verify_admin_password;

  my $newsgroup = &required_parameter( 'newsgroup_name' );

  $newsgroup =~ s/\///g;
  $newsgroup = &untaint( $newsgroup );

  my $address = &required_parameter( 'newsgroup_approved_address' );
  my $password = &required_parameter( 'newsgroup_password' );

  &user_error( "Newsgroup $newsgroup already exists" )
    if defined $newsgroups_index{$newsgroup};

  &user_error( "Password may only contain letters and digits" )
    if( ! ($password =~ /^[a-zA-Z0-9]+$/ ) );

  &begin_html( "WebSTUMP Administration: Newsgroup created" );

  print "<PRE>\n\n";

  print "Adding $newsgroup to $webstump_home/config/newsgroups.lst...";
  mkdir "$webstump_home/queues/$newsgroup", 0755;
  print " done.\n";
  
  my $dir = "$webstump_home/config/newsgroups/$newsgroup";
  
  print "Creating $dir...";
  mkdir $dir, 0755;
  print " done.\n";
  
  print "Creating files in $dir...";
  
  &append_to_file( "$dir/blacklist", "" );
  &append_to_file( "$dir/address.txt", "$address\n" );
  &append_to_file( "$dir/moderators", "ADMIN \U$password\n" );
  &append_to_file( "$dir/rejection-reasons",
"offtopic::a blatantly offtopic article, spam
harassing::message of harassing content
charter::message poorly formatted
ignore::Discard message without notifying sender (spam etc)
" );
  &append_to_file( "$dir/whitelist", "" );
  print " done.\n";


  print "</PRE>\n";

  end_html(exitButtons($base_address, userData(), 'siteAdmin'));
}

#
#
sub inline_image {
  my ($base, $file, $type) = @_;

  my ($subtype) = $type =~ m{^image/(gif|jpe?g|png)$};
  my ($extension) = $file =~ m{\.(:?gif|jpe?g|png)$}i;
  if ($subtype && $extension) {
    print qq{<img src="$base/$file">};
  } else {
    print qq{<span class="warning">$type $file not shown</span>};
  }
}

# prints warning if there is warning stored about the article
sub print_article_warning {
  my ( $newsgroup, $file ) = @_;

  my $warning_file =
    article_file_name( $newsgroup, $file ) . "/stump-warning.txt";

  if( -r $warning_file ) {
    open( WARNING, $warning_file );
    my $warning = <WARNING>;
    $warning =~ s/</&lt;/g;
    $warning =~ s/>/&gt;/g;
    close( WARNING );
    &print_image( "star.gif", "warning" );
    print "<FONT COLOR=red>$warning</FONT>\n";
    return 1;
  }

  return 0;
}

# main moderation page
sub html_moderation_screen {
  my $newsgroup = &required_parameter( 'newsgroup' );
  my $moderator = $request{'moderator'};
  my $password = $request{'password'};

  if ( ( $request{'next_screen'} || q{} ) eq 'single' ) {

    # we show a single article if the user so requested.
    # just get the first article from the queue if any, otherwise show 
    # an empty main screen.
   
    my $dir = getQueueDir($newsgroup) || error("Unknown newsgroup $newsgroup");
    opendir( QUEUE, $dir ) || error("could not open queue directory $dir");
  
    my $file;
    while ( my $subdir = readdir(QUEUE) ) {
      if ( -d "$dir/$subdir"
        && !( $subdir =~ /^\.+/ )
        && -r "$dir/$subdir/stump-prolog.txt" )
      {
	      &html_moderate_article( $subdir );
	      return;
      }
    }
  } else {
	# otherwise just show the moderator an empty main screen.
  }
    
  &begin_html( "Main Moderation Screen: $newsgroup" );
  print "Welcome to the main moderation screen. Its main purpose is to 
help you process most messages extremely quickly. For every message, it 
presents you who sent it, as well as the first three non-blank lines.
For those messages where the decision is obvious, simply select your
decision (approve/reject etc) and click submit. For those messages which
you would like to review in more details, do not select anything and
use Review/Comment function from this screen or from a subsequent screen.
Remember that if you do not make any decision, the article would stay in the
queue.\n";

  &read_rejection_reasons;

  my $dir = "$queues_dir/$newsgroup";
  opendir( QUEUE, $dir ) || &error( "could not open directory $dir" );

  print "
  <FORM METHOD=$request_method action=$base_address>
  <INPUT NAME=action VALUE=approval_decision TYPE=hidden>";
    &html_print_credentials;
  
  my $subject        = "No Subject";
  my $from           = "From nobody";
  my $form_not_empty = "";
  my $article_count = 0;
  my $warning = "";
  while ( ( defined( my $subdir = readdir(QUEUE) ) && $article_count++ < 7 ) ) {
    my ($file) = $subdir =~ m{^(\w+)$};
    next if !$file;
    next if !-d "$dir/$file";
    if ( open( my $prologFH, "<:encoding(UTF-8)", "$dir/$file/stump-prolog.txt" ) ) {
      while (<$prologFH>) {
          chomp;
        if (/^Real-Subject: (?<subject>.{0,50})/i) {
          $subject = escape_html( $+{subject} );
        } elsif (/^(?<from>From: .{0,44})/i) {
          $from = escape_html( $+{from} );
          } elsif( /^$/ ) {
            last;
          }
        }

        print "<HR><B>$from: $subject</B>(";
        print "<A HREF=$base_address?action=moderate_article&newsgroup=$newsgroup&" .
              "moderator=$moderator&password=$password&file=$file>Review/Comment/Preapprove</A>)<BR>\n";
        print "<INPUT TYPE=radio NAME=\"decision_$file\" VALUE=approve>Approve\n";
#        print "<INPUT TYPE=radio NAME=\"decision_$file\" VALUE=preapprove>PreApprove\n";
        foreach (@short_rejection_reasons) {
          print "<INPUT TYPE=radio NAME=\"decision_$file\" VALUE=\"reject $_\">Reject \u$_\n";
        }
        close($prologFH);

	print "<BR>\n";

        display_article($newsgroup, $file, "multi", 5);

        $form_not_empty = "yes";
    }
  }

  if( $form_not_empty ) {
    print "<HR> <INPUT TYPE=submit VALUE=Submit>
<INPUT TYPE=reset VALUE=Reset>
";
  } else {
    print "No articles present in the queue\n<HR>\n";
  }

  print "<A HREF=$base_address?action=change_password&newsgroup=$newsgroup&" .
        "moderator=$moderator&password=$password>Change Password</A>";


  print "</FORM>\n\n";
  closedir( QUEUE );
  end_html(exitButtons($base_address, userData(), 'articleList', $newsgroup));
}

# prints hidden fields -- credentials
sub html_print_credentials {
  my $newsgroup = $request{'newsgroup'};
  my $moderator = $request{'moderator'};
  my $password = $request{'password'};

  print "
 <INPUT NAME=newsgroup VALUE=\"$newsgroup\" TYPE=hidden>
 <INPUT NAME=moderator VALUE=\"$moderator\" TYPE=hidden>
 <INPUT NAME=password VALUE=\"$password\" TYPE=hidden>\n";
}

# newsgroup admin page
sub html_newsgroup_management {
  &begin_html( "Administer $request{'newsgroup'}" );

  print "All usernames and passwords are not case sensitive.\n";
  print "<HR>Use this form to add new moderators or change passwords:<BR>
 <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=add_user TYPE=hidden>";
  &html_print_credentials;
  print "
 Username: <INPUT NAME=user VALUE=\"\" SIZE=20>
 <BR>
 Password: <INPUT NAME=new_password VALUE=\"\" SIZE=20>
 <BR>
 <INPUT TYPE=submit VALUE=\"Add/Change\">
 <INPUT TYPE=reset VALUE=Reset>
 </FORM>
";

  print "<HR>Use this form to delete moderators:<BR>
 <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=delete_user TYPE=hidden>";
  &html_print_credentials;
  print "
 Username: <INPUT NAME=user VALUE=\"\" SIZE=20>
 <BR>
 <INPUT TYPE=submit VALUE=\"Delete Moderator\">
 <INPUT TYPE=reset VALUE=Reset>
 </FORM><HR>

 <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=edit_list TYPE=hidden>";
  &html_print_credentials;
  print "
  Configuration List: <SELECT NAME=list_to_edit>

    <OPTION VALUE=good.posters.list>Good Posters List
    <OPTION VALUE=watch.posters.list>Suspicious Posters List
    <OPTION VALUE=bad.posters.list>Banned Posters List
    <OPTION VALUE=good.subjects.list>Good Subjects List
    <OPTION VALUE=watch.subjects.list>Suspicious Subjects List
    <OPTION VALUE=bad.subjects.list>Banned Subjects List
    <OPTION VALUE=watch.words.list>Suspicious Words List
    <OPTION VALUE=bad.words.list>Banned Words List

  </SELECT>
  <INPUT TYPE=submit VALUE=\"Edit\">
  <INPUT TYPE=reset VALUE=Reset>";

  &link_to_help( "filter-lists", "filtering lists" );

  print "</FORM>\n";
  
  # Control behaviour for bad Newsgroups header
  print <<"END";
<HR>
<FORM METHOD=$request_method action=$base_address>
  <INPUT NAME=action VALUE=manage_bad_newsgroups_header TYPE=hidden>
END
  &html_print_credentials;
  print <<'END';
  <INPUT TYPE=submit VALUE="Manage bad Newsgroups header action">
</FORM>
END
  print "
  <HR>

  List of current moderators:<P>

  <UL>\n";

  foreach (keys %moderators) {
      print "<LI> $_\n";
  }

  print "</UL>\n";

  end_html(exitButtons($base_address, userData(), 'admin', $request{newsgroup}));
}

sub manage_bad_newsgroups_header {
  my ($newsgroup) = @_;
  my ($actions, $default) = get_bad_newsgroups_header_options($newsgroup);
  &read_rejection_reasons;
  my $options = [
    { value => "noAction", text => "Fix header only"},
    { value => "warn", text => "Fix header and show warning"},
    map { {value  => "reject $_", text => "reject $_: $rejection_reasons{$_}"} }
      sort(keys %rejection_reasons)
  ];

  &begin_html( "Edit bad Newsgroups header actions for $newsgroup" );
  print <<"END";
  <p>Messages sent directly to the group submission address as email
  rather than from a news client or via a news server may not have
  a Newsgroups: header of the proper form.</p>
  <p>In particular, email sent by spam-bots probably omits the header.</p>
  <p>You can select here what action to take for the various cases.</p>

<form method=$request_method action=$base_address>
END
  &html_print_credentials;

  foreach my $item (@$default) {
    if ($item->{kind}) {
      my $kind = $item->{kind};
      my $id = "kind.$kind";
      my $name = $kind;
      my $label = $item->{text};
      print <<"END";
      <p>
    <select id="$id" name="$name">
END
      foreach my $option (@$options) {
        my $selected = $actions->{$kind} eq $option->{value} ? ' selected' : q{};
      print <<"END";
     <option value="$option->{value}"$selected>$option->{text}</option>
END
      }
      print <<"END";
    </select> $label
    </p>
END
    }
  }

  print <<"END";
<button type=submit name=action value=manage_bad_newsgroups_header_set>Set</button>
<button type=submit name=action value=manage_bad_newsgroups_header_cancel>Cancel</button>
</form>
END

  end_html(exitButtons($base_address, userData(), 'admin', $newsgroup));
}

# edit config list
sub edit_configuration_list {

  my $list_to_edit = &required_parameter( 'list_to_edit' );

  $list_to_edit = &check_config_list( $list_to_edit );

  my $list_file = &full_config_file_name( $list_to_edit );

  my $list_content = "";

  if( open( LIST, $list_file ) ) {
    $list_content .= $_ while( <LIST> );
    close( LIST );
  }

  $list_content =~ s/</&lt;/g;
  $list_content =~ s/>/&gt/g;

  &begin_html( "Edit $list_to_edit" );

  print
" <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=set_config_list TYPE=hidden>
 <INPUT NAME=list_to_edit VALUE=$list_to_edit TYPE=hidden>";
  &html_print_credentials;
  &link_to_help( $list_to_edit, "$list_to_edit" );
  print "
 Edit this list: <HR>
<TEXTAREA NAME=list rows=20 COLS=50>
$list_content</TEXTAREA>

 <BR>
 <INPUT TYPE=submit VALUE=\"Set\">
 </FORM>
";

  end_html(exitButtons($base_address, userData(), 'admin', $request{newsgroup}));
}

# password change page
sub html_change_password{
  &begin_html( "Change Password" );

  print "All usernames and passwords are not case sensitive.\n";
  print "<HR>Use this form to change your password:<BR>
 <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=validate_change_password TYPE=hidden>";
  &html_print_credentials;
  print "
 <BR>
 New Password: <INPUT NAME=new_password VALUE=\"\" SIZE=20>
 <BR>
 <INPUT TYPE=submit VALUE=Submit>
 <INPUT TYPE=reset VALUE=Reset>
 </FORM>
";

  end_html(exitButtons($base_address, userData(), 'admin', $request{newsgroup}));
}


# newsgroup creation form
sub init_request_newsgroup_creation{
  my $newsgroup = &required_parameter( 'newsgroup' );

  &begin_html( "Request Creation of $newsgroup" );

  print "This page helps you ask the system administrator of your domain
to create <B>$newsgroup</B> on your server. Type in your domain name and
click SUBMIT. An email will be sent to news\@domain and usenet\@domain
and postmaster\@domain
asking them to create your newsgroup. Please do NOT abuse this system.
NOTE: You can give the URL of this page to your group readers so that 
they could request creation of their newsgroups by themselves.\n";

  print "<HR>
 <FORM METHOD=$request_method action=$base_address>
 <INPUT NAME=action VALUE=complete_newsgroup_creation_request TYPE=hidden>\n";
  &html_print_credentials;
  print "
 <BR>
 Domain Name ONLY: <INPUT NAME=domain_name VALUE=\"\" SIZE=40>
 <BR>
 <INPUT TYPE=submit VALUE=Submit>
 <INPUT TYPE=reset VALUE=Reset>
 </FORM>
";

  end_html(exitButtons($base_address, userData(), 'admin', $request{newsgroup}));
}


# newsgroup creation completion
sub complete_newsgroup_creation_request{
  my $newsgroup = &required_parameter( 'newsgroup' );
  my $domain_name = &required_parameter( 'domain_name' );

  if( !($domain_name =~ /(^[a-zA-Z0-9\.-_]+$)/) ) {
    &user_error( "invalid domain name" );
  }

  $domain_name = $1;


  my $request = "To: news\@$domain_name, usenet\@$domain_name, postmaster\@$domain_name
Subject: Please create $newsgroup (Moderated)
From: devnull\@algebra.com ($newsgroup Moderator)
Organization: stump.algebra.com

Dear News Administrator:

A user of $domain_name has requested that you create a newsgroup

	$newsgroup (Moderated) 

on your server. $newsgroup
is a legitimately created moderated newsgroup that is available worldwide.

Thank you very much for your help and cooperation.

Sincerely,

	- Moderator of $newsgroup.

";

  &email_message( $request, "news\@$domain_name" );
  &email_message( $request, "usenet\@$domain_name" );
  &email_message( $request, "postmaster\@$domain_name" );

  &begin_html( "Request to create $newsgroup sent" );

  print "The following request has been sent:<HR><PRE>\n";

  print "$request</PRE>\n";

  end_html(exitButtons($base_address, userData(), 'admin', $request{newsgroup}));
}

# displays help
sub display_help {
  my $topic_name = &required_parameter( "topic" );

  $topic_name =~ s/\///g;
  $topic_name =~ s/\.\.//g;
  $topic_name = &untaint( $topic_name );

  my $file = "$webstump_home/doc/help/$topic_name.html";

  &error( "Topic $topic_name not found in $file." ) 
	if ! -r $file;

  open( FILE, "$file" );
  my $help = "";
  $help .= $_ while( <FILE> );
  close( FILE );

  $help =~ s/##/$base_address?action=help&topic=/g;

  &begin_html( "$topic_name" );

  print $help;

  print "<HR>";
}







1;
