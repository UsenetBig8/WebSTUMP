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
# this is a collection of library functions for stump.

use warnings;

use Webstump::User qw( updateUsers isListAdmin isUserAdmin isAdmin isModerator );
use Webstump::ListAdminDisplay qw ( manageRejectionReasons );

# Declare gloal variables.
# TODO eliminate these as far as possile
our $users;
our $ignore_demo_mode;

# error message
sub error {
  my $msg = pop( @_ );

  if( defined $html_mode ) {
    print "Content-Type: text/html\n\n
<TITLE>WebSTUMP Error</TITLE>
<BODY BGCOLOR=\"#C5C5FF\" BACKGROUND=$base_address_for_files/images/bg1.jpg>
<H1>You have encountered an error in WebSTUMP.</H1>";

  &print_image( "construction.gif", "bug in WebSTUMP" );

  print " <B>$msg </B><HR>
Please cut and paste this
whole page and send it to <A HREF=mailto:$supporter>$supporter</A>.<P>
Query Parameters:<P>\n
<UL>";

    foreach (keys %request) {
      print "<LI> $_: $request{$_}\n";
    }
    exit 0;
  }

  die $msg;
}

# user error message
sub user_error {
  my $msg = pop( @_ );
  if( defined $html_mode ) {
    print "Content-Type: text/html\n\n
<TITLE>You have made a mistake.</TITLE>
<BODY BGCOLOR=\"#C5C5FF\" BACKGROUND=$base_address_for_files/images/bg1.jpg>
<H1>You have made a mistake.</H1>
  ";

  &print_image( "warning_big.gif", "Warning" );

  print " <B>$msg </B><HR>
Please go back to the previous page and correct it. If you get really
stuck, cut and paste this whole page and send it to <A
HREF=mailto:$supporter>$supporter</A>.

";

    exit 0;
  }

  die $msg;
}

sub full_config_dir_name {
  my $newsgroup = &required_parameter( "newsgroup" );
  $newsgroup =~ s/\///g;
  $newsgroup =~ s/`//g;
  $newsgroup =~ s/;//g;
  $newsgroup = &untaint( $newsgroup );
  return "$webstump_home/config/newsgroups/$newsgroup";
}

# returns full config file name
sub full_config_file_name {
  my $short_name = pop(@_);
  my $dir        = full_config_dir_name();
  return "$dir/$short_name";
}

# checks if the admin password supplied is correct
sub verify_admin_password {

  my $password = $request{'password'};

  my $password_file = "$webstump_home/config/admin_password.txt";

  open( PASSWORD, $password_file )
        || &error( "Password file $password_file does not exist" );
  my $correct_password = <PASSWORD>;
  chomp $correct_password;
  close( PASSWORD );

  &user_error( "invalid admin password" )
        if( $password ne $correct_password );

}

#
# appends a string to file.
#
sub append_to_file {
  my $msg = pop( @_ );
  my $file = pop( @_ );

  open_file_for_appending( FILE, "$file" ) 
  	|| die "Could not open $file for writing";
  print FILE $msg;
  close( FILE );
}

#
# add to config file
sub add_to_config_file {
  my $line = pop( @_ );
  my $file = pop( @_ );

print STDERR "File = $file, line= $line\n";

  if( !&name_is_in_list( $line, $file ) ) {
    &append_to_file( &full_config_file_name( $file ), "$line\n" );
  }
}


# from CGI.pm
# unescape URL-encoded data
sub unescape {
    my $todecode = shift;
    $todecode =~ tr/+/ /;       # pluses become spaces
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}
 
# sets various useful variables, etc
sub setup_variables {
  $newsgroups_list_file = "$webstump_home/config/newsgroups.lst";
}

# initializes webstump, reads newsgroups list
sub init_webstump {
  &setup_variables;

  # read the NG list
  opendir( NEWSGROUPS, "$webstump_home/config/newsgroups" )
	|| &error( "can't open $webstump_home/config/newsgroups" );

    while( $_ = readdir( NEWSGROUPS ) ) {
      my $file = "$webstump_home/config/newsgroups/$_/address.txt";
      my $ng = $_;

      next if ! -r $file;

      open( FILE, $file );
      $addr = <FILE>;
      chop $addr;
      close( FILE );

	&error( "Invalid entry $_ in the newsgroups database." )
		if( !$ng || !$addr );
        push @newsgroups_array,$ng;
        $newsgroups_index{$ng} = "$addr";
    }
  close( NEWSGROUPS );

  open( LOG, ">>$webstump_home/log/webstump.log" );
  print LOG "Call from $ENV{'REMOTE_ADDR'}, QUERY_STRING=$ENV{'QUERY_STRING'}\n";
}

# Lazy loading of the bad header options
my $bad_newsgroups_header_options = {};
sub get_bad_newsgroups_header_options {
  my ($newsgroup) = @_;
  my $default = [
    { kind => 'missing', value => 'warn', text => 'when Newsgroups header is missing'},
    { kind => 'empty', value => 'warn', text => 'when Newsgroups header is empty'},
    {
      kind  => 'nogroup',
      value => 'warn',
      text  => 'when Newsgroups header does not name the group'
    }
  ];
  
  if ($bad_newsgroups_header_options->{$newsgroup}) {
    return ($bad_newsgroups_header_options->{$newsgroup}, $default);
  }
  my $file = full_config_file_name('bad-newsgroups-header.cfg');
  # extract options and default values
  my $options = { map { ($_->{kind}, $_->{value}) } @$default };
  if (-r $file) {
    print LOG "reading options from $file\n";
    open(my $fh, "<", $file) || die "$! $file";
    while (my $line = <$fh>) {
      # skip anything of the wrong format
      if ($line =~ m/^\s*(?<opt>\w+)\s*:\s*(?<val>\w+(?:\s+\w+)*)\s*$/) {
        $options->{$+{opt}} = $+{val};
      }
    }
    close($fh);
  }
  foreach my $k (sort(keys(%$options))) {
    print LOG "option $k:$options->{$k}\n";
  }
  $bad_newsgroups_header_options->{$newsgroup} = $options;
  return ($options, $default);
}

sub manage_bad_newsgroups_header_set {
  my ($newsgroup) = @_;
  my $file = full_config_file_name('bad-newsgroups-header.cfg');
  my ($opts, $default) = get_bad_newsgroups_header_options($newsgroup);

printf LOG "Writing actions to $file\n";
  open_file_for_writing( LIST, "$file.new" ) 
    || &error( "Could not open $file for writing" );
  foreach my $item (@$default) {
    my $k = $item->{kind};
    $opts->{$k} = $request{$k};
    printf LIST "%s:%s\n", $k, $opts->{$k};
printf LOG "%s:%s\n", $k, $opts->{$k};
  }
  close( LIST );
  rename ("$file.new", "$file");
}

# gets the directory name for the newsgroup
sub getQueueDir {
  my $newsgroup = pop( @_ );
  if( $newsgroups_index{$newsgroup} ) {
    return "$queues_dir/$newsgroup";
  } 
  return ""; # undefined ng
}

# reads request, if any
sub readWebRequest {
  my @query;
  my %result;
  if( defined $ENV{"QUERY_STRING"} ) {

    @query = split( /&/, $ENV{"QUERY_STRING"} );
    foreach( @query ) {
      my ($name, $value) = split( /=/ );
      $result{&unescape($name)} = &unescape( $value );
    }
  }

  while(<STDIN>) {
    @query = split( /&/, $_ );
    foreach( @query ) {
      my ($name, $value) = split( /=/ );
      $result{&unescape($name)} = &unescape( $value );
    }
  }

  foreach( keys %result ) {
    print LOG "Request: $_ = $result{$_}\n" if( $_ ne "password" );
  }
  return %result;
}

# Checks if the program is running in a demo mode
sub is_demo_mode {
  return &optional_parameter( 'newsgroup' ) eq "demo.newsgroup" 
  	 && !$ignore_demo_mode;
}

# opens file for writing
sub open_file_for_writing { # filehandle, filename
  my $filename = pop( @_ );
  my $filehandle = pop( @_ );

  if( &is_demo_mode ) {
	return( open( $filehandle, ">/dev/null" ) );  
  } else {
	return( open( $filehandle, ">$filename" ) );
  }
}

# opens pipe for writing
sub open_pipe_for_writing { # filehandle, filename
  my $filename = pop( @_ );
  my $filehandle = pop( @_ );

  if( &is_demo_mode ) {
	return( open( $filehandle, ">/dev/null" ) );  
  } else {
	return( open( $filehandle, "|$filename" ) );
  }
}

# opens file for appending
sub open_file_for_appending { # filehandle, filename
  my $filename = pop( @_ );
  my $filehandle = pop( @_ );

  if( &is_demo_mode ) {
	return( open( $filehandle, ">>/dev/null" ) );  
  } else {
	return( open( $filehandle, ">>$filename" ) );
  }
}

# gets a parameter
sub get_parameter {
  my $arg = pop( @_ );
  return "" if( ! defined $request{$arg} );
  return $request{$arg};
}

# barfs if the required parameter is not supplied
sub required_parameter {
  my $arg = pop( @_ );
  user_error( "Parameter \"$arg\" is not defined or is empty" )
	if( ! defined $request{$arg} || !$request{$arg} );
  return $request{$arg};
}

# optional request parameter
sub optional_parameter {
  my $arg = pop( @_ );
  return $request{$arg};
}

# issues a security alert
sub security_alert {
  my $msg = pop( @_ );
  print LOG "SECURITY_ALERT: $msg\n";
}

# authenticates user
sub authenticate {
  my ( $newsgroup, $moderator, $password ) = @_;
  
  $users = Webstump::User::readUsersFromFile();
  my $id = uc($moderator // q{});
  my $pw = uc($password // q{});

  if ( !defined $users->{$id}
    || $users->{$id}->{pw} ne $pw )
  {
    &security_alert("Authentication denied.") & user_error("Authentication denied.");
  } else {
    return $users->{$id};
  }
}

# cleans request of dangerous characters
sub disinfect_request {
  if( defined $request{'newsgroup'} ) {
    $newsgroup = $request{'newsgroup'};
    $newsgroup =~ s/\///g;
    $newsgroup =~ s/`//g;
    $newsgroup =~ s/\>//g;
    $newsgroup =~ s/\<//g;
    $newsgroup =~ s/ //g;
    $newsgroup =~ s/|//g;
    $newsgroup = &untaint( $newsgroup );
    $request{'newsgroup'} = $newsgroup;
  }

  if( defined $request{'file'} ) {
    my $file = $request{'file'};
    $file =~ s/\///g;
    $file =~ /(^.*$)/;
    $file = $1;
    $request{'file'} = $file;
  }
}

# adds a user
# TODO replace this function with user management
sub add_user {
  my $user = &required_parameter( "user" );
  my $new_password = &required_parameter( "new_password" );

  &user_error( "Username may only contain letters and digits" )
    if( ! ($user =~ /^[a-zA-Z0-9]+$/ ) );
  &user_error( "Password may only contain letters and digits" )
    if( ! ($new_password =~ /^[a-zA-Z0-9]+$/ ) );
  my $id = "\U$user";
  my $pw = "\U$new_password";
  if ( exists( $users->{$id} ) ) {
    user_error("user $id already exists");
  } else {
    # Note that the existing user check above prevents adding 'admin'
    # so in this legacy context we are adding a moderator
    Webstump::User::addUser( $users, $id, $pw, \%request );
  }

  return if is_demo_mode();
  Webstump::User::saveUsersToFile($users);
}

# checks that a config list is in enumerated set of values. Returns 
# untainted value
sub check_config_list {
  my $list_to_edit = pop( @_ );

 &user_error( "invalid list name $list_to_edit" )
    if( $list_to_edit ne "good.posters.list"
        && $list_to_edit ne "watch.posters.list"
        && $list_to_edit ne "bad.posters.list"
        && $list_to_edit ne "good.subjects.list"
        && $list_to_edit ne "watch.subjects.list"
        && $list_to_edit ne "bad.subjects.list"
        && $list_to_edit ne "bad.words.list"
        && $list_to_edit ne "watch.words.list" );

  return &untaint( $list_to_edit );
}

# sets a configuration list (good posters etc)
sub set_config_list {
  my $list_content = $request{"list"};
  my $list_to_edit = &required_parameter( "list_to_edit" );

  $list_content .= "\n";
  $list_content =~ s/\r//g;
  $list_content =~ s/\n+/\n/g;
  $list_content =~ s/\n +/\n/g;
  $list_content =~ s/^\n+//g;

  $list_to_edit = &check_config_list( $list_to_edit );

  my $list_file = &untaint( &full_config_file_name( $list_to_edit ) );

  open_file_for_writing( LIST, "$list_file.new" ) 
    || &error( "Could not open $list_file for writing" );
  print LIST $list_content;
  close( LIST );

  rename ("$list_file.new", "$list_file");
}

# validate password change
sub validate_change_password {
  my ($newsgroup, $user) = @_;
  my $pwuser       = required_parameter("update");
  my $new_password = required_parameter("${pwuser}-pw");
  if ($user->{id} eq $pwuser || isUserAdmin($user)) {
  &user_error( "Password may only contain letters and digits" )
    if( ! ($new_password =~ /^[a-zA-Z0-9]+$/ ) );
  &user_error( "Cannot change password for user admin" )
    if ( "\U$pwuser" eq "ADMIN" );

  Webstump::User::changePassword( $users, "\U$pwuser", "\U$new_password" );
  Webstump::User::saveUsersToFile($users);

  } else {
      &security_alert("User $user->{id} tried to change password for $pwuser");
      &user_error("Only users with admin rights can change other users passwords");
  }
  # Go to welcome page when changing your own password
  if ($user->{id} eq $pwuser) {
    html_welcome_page();
  } else {
    html_newsgroup_management($newsgroup, $user);
  }
}

# email_message message recipient
sub email_message {
  my $recipient = pop( @_ );
  my $message = pop( @_ );

  my $sendmail = "";

  foreach (@sendmail) {
    if( -x $_ ) {
      $sendmail = $_;
      last;
    }
  }
 
  &error( "Sendmail not found" ) if( !$sendmail );
 
  my $sendmail_command = "$sendmail $recipient";
  $sendmail_command =~ /(^.*$)/; 
  $sendmail_command = $1; # untaint
  open_pipe_for_writing( SENDMAIL, "$sendmail_command > /dev/null " );
  print SENDMAIL $message;
  close( SENDMAIL );
                
}

sub article_file_name {
  my ($newsgroup, $file) = @_;
  return "$queues_dir/$newsgroup/$file";
}

sub untaint {
  $arg = pop( @_ );
  $arg =~ /(^.*$)/;
  return $1;
}

sub rmdir_rf {
  my $dir = pop( @_ );

  return if &is_demo_mode;

  $dir = &untaint( $dir );
  opendir( DIR, $dir ) || return;
  while( $_ = readdir(DIR) ) {
    unlink &untaint( "$dir/$_" );
  }
  closedir( DIR );
  rmdir( $dir );
}

sub approval_decision {
  $newsgroup = &required_parameter( 'newsgroup' );
  my $comment = &get_parameter( 'comment' );
  my $decision = "";

  my $poster_decision = &optional_parameter( "poster_decision" );
  my $thread_decision = &optional_parameter( "thread_decision" );
  
  foreach( keys %request ) {
    if( /^decision_/ ) {
      $decision = $request{$_};
      s/decision_//;
      s/\///;
      my $file = &untaint( $_ );

      my $fullpath = article_file_name($newsgroup, $file) . "/stump-prolog.txt"; # untainted

      $decision = "reject thread" if $thread_decision eq "ban";
      $decision = "approve" if $thread_decision eq "preapprove";

      $decision = "reject abuse" if $poster_decision eq "ban";
      $decision = "approve" if $poster_decision eq "preapprove";

      if( -r $fullpath && open( my $prologFH, "<:encoding(UTF-8)", "$fullpath" ) ) {

        my $RealSubject = "", $From = "", $Subject = "";
        while( <$prologFH> ) {
          if( /^Subject: /i ) {
	    chop;
            $Subject = $_;
	    $Subject =~ s/Subject: +//i;
          } elsif( /^Real-Subject: /i ) {
	    chop;
            $RealSubject = $_;
	    $RealSubject =~ s/Real-Subject: +//i;
	    $RealSubject =~ s/Re: +//i;
          } elsif( /^From: / ) {
	    chop;
            $From = $_;
	    $From =~ s/From: //i;
          }
          last if /^$/;
        }
        close $prologFH;

        &add_to_config_file( "good.posters.list", $From ) 
		if $poster_decision eq "preapprove";

        &add_to_config_file( "good.subjects.list", $RealSubject ) 
		if $thread_decision eq "preapprove";

        &add_to_config_file( "bad.posters.list", $From ) 
		if $poster_decision eq "ban";

        &add_to_config_file( "bad.subjects.list", $RealSubject ) 
		if $thread_decision eq "ban";

        &add_to_config_file( "watch.subjects.list", $RealSubject ) 
		if $thread_decision eq "watch";

# Subject, newsgroup, ShortDirectoryName, decision, comment
        &process_approval_decision( $Subject, $newsgroup, $file, $decision, $comment );

      }
    }
  }

  &html_moderation_screen;
}

# gets the count of unapproved articles sitting in the queue
sub get_article_count {
  my $newsgroup = pop( @_ );
   my $count = 0;
   my $dir = &getQueueDir( $newsgroup );
   opendir( DIR, $dir );
   my $file;
   while( $file = readdir( DIR ) ) {
    $count++
      if ( -d "$dir/$file" && $file ne "." && $file ne ".." && -r "$dir/$file/full_message.txt" );
   }

   return $count;
}

# processes web request
sub processWebRequest {

  my $action = $request{'action'};
  my $newsgroup = $request{'newsgroup'};
  my $moderator = $request{'moderator'};
  my $password = $request{'password'};

  $moderator = "\L$moderator" if defined($moderator);

  # listAdmin actions are processed in a standard way.
  # If the action returns true (1) show the management page
  # otherwise the action has shown a different page.
  my $ListAdminActions = {
    manageRejectionReasons => {
      action => sub { return manageRejectionReasons($base_address, $_[0], \%request, $newsgroup); },
      description => 'manage rejection reasons'
    },
    edit_list => {
      action => sub { edit_configuration_list(); return 0; },
      description => 'edit lists'
    },
    set_config_list => {
      action => sub { set_config_list(); return 1; },
      description => 'update configuration'
    },
    manage_bad_newsgroups_header => {
      action => sub { manage_bad_newsgroups_header($newsgroup); return 0;},
      description => 'manage bad newsgroups header actions'
    },
    manage_bad_newsgroups_header_set => {
      action => sub { manage_bad_newsgroups_header_set($newsgroup); return 1;},
      description => 'manage bad newsgroups header actions'
    },
    manage_bad_newsgroups_header_cancel => {
      action => sub { return 1; },
      description => 'manage bad newsgroups header actions'
    },
  };
  if( my $actionSpec = $ListAdminActions->{$action} ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isListAdmin($user) ) {
      if ($actionSpec->{action}->($user)) {
        html_newsgroup_management( $newsgroup, $user );
      }
    } else {
      &security_alert( "User $moderator tried to $actionSpec->{description} in $newsgroup" );
      &user_error("Only users with list admin rights can $actionSpec->{description}");
    }
  } elsif( $action eq "login_screen" ) {
    &html_login_screen;
  } elsif( $action eq "moderation_screen" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( $user->{moderate} ) {
      &html_moderation_screen;
    } else {
      html_newsgroup_management( $newsgroup, $user );
    }
  } elsif ( $action eq "management_screen" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isAdmin($user) ) {
      html_newsgroup_management( $newsgroup, $user );
    } else {
      &security_alert( "Moderator $moderator tried to manage $newsgroup" );
      &user_error("Only users with admin rights can manage newsgroup");
    }
  } elsif ( $action eq "updateUsers" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isUserAdmin($user) ) {
      if ( my $pwChange = $request{newPassword} ) {
        if ($users->{$pwChange}) {
          html_change_password( $newsgroup, $user, untaint($pwChange) );
        } else {
          html_newsgroup_management( $newsgroup, $user );
        }
      } else {
        updateUsers( \%request, $newsgroup, $users );
        html_newsgroup_management( $newsgroup, $user );
      }
    } else {
      &security_alert( "User $moderator tried to update users in $newsgroup" );
      &user_error("This action requires user admin rights");
    }
  } elsif( $action eq "add_user" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isUserAdmin($user) ) {
      &add_user;
      html_newsgroup_management( $newsgroup, $user );
    } else {
      &security_alert( "Moderator $moderator tried to add user in $newsgroup" );
      &user_error("Only users with admin rights can add or delete users");
    }
  } elsif( $action eq "approval_decision" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isModerator($user) ) {
      &approval_decision;
    } else {
      &security_alert("user $moderator tried $action in $newsgroup");
      &user_error( "Moderator rights are required for this action" );
    }
  } elsif( $action eq "moderate_article" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    if ( isModerator($user) ) {
      &html_moderate_article();
    } else {
      &security_alert("user $moderator tried $action in $newsgroup");
      &user_error( "Login ADMIN exists for user management only" );
    }
  } elsif( $action eq "change_password" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    html_change_password( $newsgroup, $user, $user->{id} );
  } elsif( $action eq "validate_change_password" ) {
    my $user = authenticate( $newsgroup, $moderator, $password );
    validate_change_password($newsgroup, $user);
  } elsif( $action eq "init_request_newsgroup_creation" ) {
    &init_request_newsgroup_creation;
  } elsif( $action eq "complete_newsgroup_creation_request" ) {
    &complete_newsgroup_creation_request;
  } elsif( $action eq "webstump_admin_screen" ) {
    &webstump_admin_screen;
  } elsif( $action eq "admin_login" ) {
    &admin_login_screen;
  } elsif( $action eq "admin_add_newsgroup" ) {
    &admin_add_newsgroup;
  } elsif( $action eq "help" ) {
    &display_help;
  } else {
    &error( "Unknown user action: '$action'" );
  }
}


1;
