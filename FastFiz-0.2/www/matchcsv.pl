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
my $sth=$Pool::dB::dbh->prepare_cached('SELECT noise,sim_limit,end_reason FROM noise_sim_scatterplot WHERE matchid=?',{},1);
$sth->execute($matchid);
#print "noise,win,lose,timeout\n";
while (my ($noise,$sim,$end)=$sth->fetchrow_array()) {
  next if ($end == 4 || $end==3);
  print "$noise,$sim,".($end == 1?1:0)."\n";
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
