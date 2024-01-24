package Pool::AJAX;
use strict;
use DBI;
use Exporter;
use CGI;
use CGI::Ajax;
use Pool::dB;

our @EXPORT = qw(getAPIURL);
our @ISA = qw(Exporter);

our $table;
our $key;

sub go{
  $table=shift;
  $key=shift;
  my $html=shift;
  my $pjx=new CGI::Ajax('test_func'=>\&test_func,'submit_change'=>\&submit_change,
                        'update_tablestate'=>\&update_tablestate,
                        'ajax_delete'=>\&ajax_delete);
  $pjx->JSDEBUG(2);
  $pjx->DEBUG(1);
  CGI::param();
  my $val=CGI::param($key);
  if (CGI::param('edit') && ownok($table,$key,$val)) {
    my @cols;
    my @vals;
    for my $p (CGI::param()) {
      next unless $p =~ /^db_(.*)$/;
      my $col=sanatize($1);
      push @cols,$col;
      my $uval=CGI::param($p);
      undef $uval if ($uval eq '*NULL*');
      print STDERR "REVMAP $col $uval\n";
      $uval=colmap('reverse',$col,$uval);
      push @vals,$uval;
    }
    print STDERR update($table,$key,$val,\@cols,\@vals);
    $Pool::dB::dbh->commit();
  }
  if (CGI::param('insert') && (userid() == -1 || userid() == CGI::param('db_owner'))) {
    my %record;
    for my $p (CGI::param()) {
      next unless $p =~ /^db_([A-Za-z0-9_]+)$/;
      my $col=$1;
      my $uval=CGI::param($p);
      undef $uval if ($uval eq '*NULL*');
      print STDERR "REVMAP $col $uval\n";
      $uval=colmap('reverse',$col,$uval);
      $record{$col}=$uval;
    }
    my $newval=db_insert($table,\%record);
    if ($newval) {
      $Pool::dB::dbh->commit();
      CGI::param($key,$newval);
      CGI::param('key',$newval);
    }
  }
  if (CGI::param('add') && (userid() == -1 || ownok('tournaments','tournamentid',CGI::param('key')) )) {
    my %record;
    for my $p (CGI::param()) {
      next unless $p =~ /^add_([A-Za-z0-9_]+)$/;
      my $col=$1;
      my $uval=CGI::param($p);
      undef $uval if ($uval eq '*NULL*');
      print STDERR "REVMAP $col $uval\n";
      $uval=colmap('reverse',$col,$uval);
      print STDERR "AFTER REVMAP = $uval\n";
      $record{$col}=$uval;
    }
    $record{tournamentid}=CGI::param('key');
    db_insert('tournament_agents',\%record,1);
    $Pool::dB::dbh->commit();
  }
  if (CGI::param('start') && (userid() == -1 || ownok('tournaments','tournamentid',CGI::param('key')) )) {
    $Pool::dB::dbh->do('SELECT populate_tournament(?)',{},CGI::param('key'));
    $Pool::dB::dbh->commit();
  }
  print STDERR "before build_html\n";
  return $pjx->build_html($CGI::Q,$html);
  print STDERR "after build_html\n";
}

sub test_func {
  my $input = shift;
  return $input." yes!";
}

sub sanatize {
  my $arg=shift;
  $arg =~ s{[^A-Za-z0-9_]}{}go;
  return $arg;
}

sub submit_change {
  my ($val,$ucol,$uval)=@_;
  return unless ownok($table,$key,$val);
  $ucol=sanatize($ucol);
  undef $uval if ($uval eq '*NULL*');
  my $ret=update($table,$key,$val,$ucol,$uval);
  $Pool::dB::dbh->commit();
  return $ret;
}

sub ajax_delete {
  my ($val,$agentid)=@_;
  return unless ownok('tournaments','tournamentid',$val);
  if ($Pool::dB::dbh->do('DELETE FROM tournament_agents WHERE tournamentid=? AND agentid=?',{},$val,$agentid)) {
    $Pool::dB::dbh->commit();
    return $agentid;
  } else {
    return 0;
  }
}

sub update_tablestate {
  return unless (userid() == -1);
  my ($stateid,$ball,$x,$y)=@_;
  my $ret=update('tablestates',['stateid','ball'],[$stateid,$ball],['x','y','status'],[$x,$y,1]);
  $Pool::dB::dbh->commit();
  return $ret;
}

sub getAPIURL {
  my $url=CGI::url();
  $url =~ s{[^/]+$}{api.pl};
  return $url;
}

1;