#!/usr/bin/perl -wT
use strict;
use CGI qw/:standard/;

BEGIN
{
  push @INC,'.';
}
use Pool::dB;

chkauth();

if (param('gameid')) {
  my $gameid=param('gameid');
  if (check_access('game',$gameid)) {
    print header(-type=>'text/x-pool-logfile',-attachment=>"$gameid.log");
    my $log=$Pool::dB::dbh->selectrow_array('SELECT logfile FROM game_logfiles WHERE gameid=?',{},$gameid);
    print $log;
  } else {
    print header;
    print perm_err();
  }
}

