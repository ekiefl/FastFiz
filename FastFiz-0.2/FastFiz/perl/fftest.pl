#!/usr/bin/perl -w
use Pool;
use Data::Dumper;
use Pool::Rules;

print Pool::Fiz::getFastFizVersion()."\n";
print Pool::Rules::getRulesVersion()."\n";
my $state;
while (<>) {
#  print;
  if (m{TSTATE (.+)$}o) {
    my $tsstring=$1;
    $state=new Pool::Fiz::TableState();
    $state->fromString($tsstring);
  } elsif (m{TSHOT ([-\.\d]+) ([-\.\d]+) ([-\.\d]+) ([-\.\d]+) ([-\.\d]+)$}o) {
    my $sp = new Pool::Fiz::ShotParams($1,$2,$3,$4,$5);
    my $shot=$state->executeShot($sp,1,1);
    print "\n\n";
    print $state->toString();
    print "\n\n";
    my @evlist=$shot->getEventList();
    print Dumper([map {$_->toString()} @evlist]);
  }
}