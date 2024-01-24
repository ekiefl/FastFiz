#!/usr/bin/perl -wT
use strict;
use CGI qw/:standard/;

BEGIN
{
  push @INC,'.';
}
use Pool::dB;

chkauth();
my $matchid=param('matchid');
unless (ownok('matches','matchid',$matchid)) {
  print header('text/html');
  print perm_err();
  exit;
}
print header('text/csv');
my $sth=$Pool::dB::dbh->prepare_cached('SELECT noise,sim_limit,end_reason,balls_left FROM noise_sim_ballsleft_surface WHERE matchid=?',{},1);
$sth->execute($matchid);
#print "noise,win,lose,timeout\n";
while (my ($noise,$sim,$end,$left)=$sth->fetchrow_array()) {
  next if ($end == 4 || $end==3);
  if ($end == 1) {
    $left=0;
  } elsif ($end != 7) {
    $left=8;
  }
  print "$noise,$sim,$left\n";
#  if ($end == 1) {
#    print "$noise,$sim,,\n";
#  } elsif ($end == 3) {
#    print "$noise,,,$sim\n";
#  } elsif ($end == 4) {
#    next;
#  } else {
#    print "$noise,,$sim,\n";
#  }
}
$sth->finish();
