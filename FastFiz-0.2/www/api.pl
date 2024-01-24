#!/usr/bin/perl -wT
use strict;
BEGIN
{
  $ENV{FASTFIZHOME}='../FastFiz/';
  push @INC,$ENV{FASTFIZHOME}."/perl";
  push @INC,'.';
}

use Pool;
use Pool::dB;
use Data::Dumper;
use XMLRPC::Transport::HTTP;

our $TEST;

sub readlog {
  my $logid=shift;
  my $secret=shift;
  my $logdata=$Pool::dB::dbh->selectrow_array('SELECT logdata FROM logfiles WHERE logid=? AND secret=?;',{},$logid,$secret) or die DBI::errstr;
  die "Bad log ID\n" unless $logdata;
  my $log;
  open $log, '<', \$logdata;
  my $gtype;
  my $gstate;
  my $state;
  my @res;
  print STDERR "readlog\n";
  while (<$log>) {
    chomp;
    if (/^GTYPE (\d+)$/) {
      $gtype=$1;
    } elsif (/^STATE (.+)$/) {
      # TODO: add states with no shots
      my $gsstring=$1;
      $gstate=Pool::Rules::GameState::Factory($gsstring);
      $state=$gstate->tableState();
    } elsif (/^TSTATE (.+)$/) {
      my $tsstring=$1;
      $state=new Pool::Fiz::TableState();
      $state->fromString($tsstring);
      undef $gstate;
    } elsif (/^TSHOT\s+((?:[-\d\.]+\s+){4}[-\d\.]+)$/ ||
             /^SHOT\s+((?:[-\d\.]+\s+){17})(.+?)\s+"(.*?)"\s+"(.*?)"$/) {
      print STDERR "Got shot\n";
      my %data;
      my ($shotinfo);
      ($shotinfo,@data{qw/noise agentname oppname/})=($1,$2,$3,$4);
      print STDERR "SI: $shotinfo\n";
#      ($shotinfo,@data{qw/agentname oppname/})=($1,$2,$3,$4);
      $data{shotinfo}=$shotinfo;
      @data{qw/a b theta phi v nl_a nl_b nl_theta nl_phi nl_v ball pocket decision cue_x cue_y timespent duration/}=
        split(' ',$shotinfo);
      if ($data{cue_x}) {
#        print STDERR "Put Cue at ".$data{cue_x}."/".$data{cue_y}."\n";
        $state->setBall($Pool::Fiz::Ball::CUE,$Pool::Fiz::Ball::STATIONARY,$data{cue_x},$data{cue_y});
      };
      $data{state}=$state->toPerl();
      if ($gstate) {
        @data{qw/turntype playing_solids timeleft timeleft_opp/}=
          ($gstate->getTurnType,
           $gstate->isOpenTable()?undef:$gstate->playingSolids,
           $gstate->timeLeft(),
           $gstate->timeLeftOpp());
      }
      unless ($data{duration}) {
        my $sp = new Pool::Fiz::ShotParams(@data{qw/a b theta phi v/});
        eval {
          $data{duration}=$state->executeShot($sp,0)->getDuration();
        };
        if ($@) {
          print STDERR "ERROR EXECUTING!\n$@\n";
          next;
        }
      }
      # TODO: send noise info to client.
#      print STDERR Dumper(\%data);
      push @res,\%data;
    } else {
#      print STDERR "X$_";
      # TODO: handle TSTATE and TSHOT
    }
  }
  return \@res;
}

sub getgame {
  shift;
  my $sh=shift;
  my @ret;
  my $id=$sh->{gameid};
  my $idtype;
  if ($id =~ /^\d+$/) {
    $idtype='gameid';
    if ($id<0) {
      $idtype='shotid';
      $id=-$id;
    }
  } elsif ($id =~ /^G(\d+)$/) {
    $id=$1; $idtype='gameid';
  } elsif ($id =~ /^S(\d+)$/) {
    $id=$1; $idtype='shotid';
  } elsif ($id =~ /^L(\d+)-(\d+)$/) {
    return readlog($1,$2);
  } else {
    die "Bad gameid - $id\n";
  }
  if ($TEST || check_access(($idtype eq 'gameid'?'game':'shot'),$id)) {
    my $sth=$Pool::dB::dbh->prepare_cached(<<"EOF");
      select prev_state as state,agentid,
         (select agentid1+agentid2-agentid from games where gameid=sh.gameid) as opp_agentid,
         a,b,theta,phi,v,cue_x,cue_y,decision,ball,pocket,
         nl_a,nl_b,nl_theta,nl_phi,nl_v,
         timespent,turntype,playing_solids,
         timeleft,timeleft_opp,duration,shotid 
       from shots sh join states st on sh.prev_state=st.stateid where ${idtype}=? order by shotid;
EOF
    $sth->execute($id);
    while (my $data=$sth->fetchrow_hashref()) {
      my $state=new Pool::Fiz::TableState();
      $state->fromDb($data->{state});
      if ($data->{cue_x}) {
        $state->setBall($Pool::Fiz::Ball::CUE,$Pool::Fiz::Ball::STATIONARY,$data->{cue_x},$data->{cue_y});
      };
      unless (defined ($data->{ball})) {
        $data->{ball}=$Pool::Fiz::Ball::UNKNOWN_ID;
        $data->{pocket}=$Pool::Fiz::Table::UNKNOWN_POCKET;
      }
      $data->{state}=$state->toPerl();
      unless (defined ($data->{duration})) {
        my $sp = new Pool::Fiz::ShotParams($data->{a},$data->{b},$data->{theta},$data->{phi},$data->{v});
        eval {
          $data->{duration}=$state->executeShot($sp,0)->getDuration();
        };
        if ($@) {
          print STDERR "$@";
          next;
        };
        $Pool::dB::dbh->do('UPDATE shots SET duration=? WHERE shotid=?',{},$data->{duration},$data->{shotid});
      }
      next unless $data->{duration};
      push @ret,$data;
    }
    $Pool::dB::dbh->commit();
  }
  return \@ret;
}
  
sub coltext {
  # Usage: coltext(column_name,column_value)
  # Will lookup text string for that column in appropriate table.
  shift;
  ### SQL INJECTION? ###
  return Pool::dB::colmap('text_auth',@_);
}

sub coltitle {
  shift;
  return Pool::dB::colmap('title',@_);
}

sub dump {
  return join('|',@_);
}

sub gettestgame() {
  $TEST=1;
  return getgame(undef,{gameid=>4669});
}

sub _execshot {
#  print STDERR Dumper(\@_);
  my ($state,$sp);
  if (@_) {
    $state=shift;
    my ($a,$b,$theta,$phi,$v)=@_;
    $sp = new Pool::Fiz::ShotParams($a,$b,$theta,$phi,$v);
  } else {
    $state=Pool::Fiz::getTestState();
    $sp=Pool::Fiz::getTestShotParams();
  }
  my @result=({time=>0,state=>$state->toPerl(1)});
  my $gshot;
  eval {
    #open OLDOUT, ">&STDOUT" or die "Can't dup STDOUT: $!";
    #open OLDERR, ">&STDERR" or die "Can't dup STDERR: $!";
    #close STDOUT; close STDERR;
    $gshot=$state->executeShot($sp,0);
    #open STDERR, ">&OLDERR";
    #open STDOUT, ">&OLDOUT";
  };
  if ($@) {
    print STDERR "ERROR IN _EXECSHOT!****************************\n$@\n*************************************\n";
    print STDERR Pool::Fiz::getFastFizVersion();
    return [];
  }
  my @evlist=$gshot->getEventList();
#  print STDERR Dumper(map {$_->toString()} @evlist);
  for my $ev (@evlist) {
    {
      my %e;
      $e{time}=$ev->getTime();
#      $gshot->getStateAt($e{time},$gstate);
#      $gstate->toFizTableState($state);
      my @bd=($ev->getBall1Data());
#      print STDERR "got ball 1 data\n";
      push @bd,$ev->getBall2Data() unless $ev->getBall2() == $Pool::Fiz::Ball::UNKNOWN_ID;
      my @pbd=map {$_->toPerl(1);} @bd;
      $e{changes}=\@pbd;
      #$e{state}=$state->toPerl(@bd);
      push @result,\%e;
    }
  }
  return \@result;
}

sub execshot {
  shift;
  my $sh=shift;
  my $state=new Pool::Fiz::TableState();
  $state->fromPerl($sh->{state});
  return _execshot($state,$sh->{a},$sh->{b},$sh->{theta},$sh->{phi},$sh->{v});
}

sub testshot {
  my $state=new Pool::Fiz::TableState();
  #$state->fromPerl($Pool::TESTPOS);
  #$state->setBall(0,$Pool::Fiz::Ball::STATIONARY,0.48,1.67705);
  #$state->fromString("16 0.028575 1 0 0.55800000000000005151 1.6770000000000000462 0.028574999999999999706 1 1 0.55800000000000005151 0.5590000000000000524 0.028574999999999999706 1 2 0.52942499999999903526 0.50950664817371837945 0.028574999999999999706 1 3 0.58657500000000106777 0.50950664817371837945 0.028574999999999999706 1 4 0.50084999999999901821 0.46001329634743670649 0.028574999999999999706 1 5 0.55800000000000005151 0.46001329634743670649 0.028574999999999999706 1 6 0.61515000000000108482 0.46001329634743670649 0.028574999999999999706 1 7 0.47227499999999805746 0.41051994452115503353 0.028574999999999999706 1 8 0.52942499999999903526 0.41051994452115503353 0.028574999999999999706 1 9 0.58657500000000106777 0.41051994452115503353 0.028574999999999999706 1 10 0.64372500000000210107 0.41051994452115503353 0.028574999999999999706 1 11 0.44369999999999804041 0.36102659269487336058 0.028574999999999999706 1 12 0.50084999999999901821 0.36102659269487336058 0.028574999999999999706 1 13 0.55800000000000005151 0.36102659269487336058 0.028574999999999999706 1 14 0.61515000000000108482 0.36102659269487336058 0.028574999999999999706 1 15 0.67230000000000200711 0.36102659269487336058");
  return _execshot();#($state,0,0,25.0,270.0,10);
}

### SERVER CODE ###

sub authenticate_agent {
  my ($agentid,$password)=@_;
  my $realpw=$Pool::dB::dbh->selectrow_array('SELECT passwd FROM agents WHERE agentid=?',{},$agentid) or die DBI::errstr;
  return ($realpw eq $password); # TODO: hash
}

sub register_agent {
  shift;
  my ($name,$config,$password,$owner) = @_;
  undef $owner unless $owner;
  unless ($owner =~ /^\d+$/) {
    $owner=$Pool::dB::dbh->selectrow_array('SELECT userid FROM users WHERE username=?',{},$owner);
  }
  print STDERR "register_agent: ",join('|',@_);
  my $agentid=$Pool::dB::dbh->selectrow_array('SELECT agentid FROM agents WHERE agentname=? AND config=?',{},$name,$config);
  if ($agentid) {
    return "Bad password" unless authenticate_agent($agentid,$password);
  } else {
    $Pool::dB::dbh->do('INSERT INTO agents (agentname,config,passwd,owner) VALUES (?,?,?,?)',{},$name,$config,$password,$owner) or die DBI::errstr;
    $agentid=$Pool::dB::dbh->selectrow_array('SELECT lastval();') or die DBI::errstr;
    $Pool::dB::dbh->commit();
  }
  return $agentid;
}

sub get_shot {
  shift;
  my ($agentid,$password)=@_;
  print STDERR "authenticating..\n";
  return "Bad password" unless authenticate_agent($agentid,$password);
  print STDERR "auth OK..\n";
  $Pool::dB::dbh->do('SELECT cleanup_pendingshots();') or die DBI::errstr;
  $Pool::dB::dbh->commit();
  my ($gameid,$stateid,$priority)=$Pool::dB::dbh->selectrow_array('SELECT gameid,stateid,priority FROM select_pending_shot(?);',{},"{$agentid}") or die DBI::errstr;
  my ($matchid,$matchpriority)=$Pool::dB::dbh->selectrow_array('SELECT matchid,priority FROM select_pending_match(?);',{},"{$agentid}") or die DBI::errstr;
  if (!$gameid && !$matchid) { # No shots available
    return {shot_available => SOAP::Data->type(boolean=>0)};
  } 
  if ($matchid && (!$gameid || $matchpriority>$priority)) { # New game in match
    print STDERR "New game in match $matchid\n";
    my ($gametype,$timeleft,$timeleft_opp)=$Pool::dB::dbh->selectrow_array('SELECT gametype,timelimit1,timelimit2 FROM matches WHERE matchid=?',{},$matchid) or die DBI::errstr;
    print STDERR "Match info: $gametype,$timeleft,$timeleft_opp\n";
    my $initstate=Pool::Rules::GameState::RackedState($gametype); # Should be changed to accept time limts
    ### SPECIAL TEST ###
    my $special;
    if ($timeleft eq '01:00:00') {
      $timeleft=$Pool::dB::dbh->selectrow_array(qq{SELECT random()*'5 min'::interval + '1 min'::interval;}) or die DBI::errstr;      print STDERR "Time limit for this game: $timeleft\n";
      $special=1;
    }
    print STDERR "Initial state: ".$initstate->toString()."\n";
    $stateid=$initstate->addToDb($timeleft,$timeleft_opp);
    print STDERR "New stateid $stateid\n";
    if ($special) {
      $gameid=$Pool::dB::dbh->selectrow_array('SELECT add_game_to_match_special(?,?)',{},$matchid,$stateid) or die DBI::errstr;;
    } else {
      $gameid=$Pool::dB::dbh->selectrow_array('SELECT add_game_to_match(?,?,?)',{},$matchid,$agentid,$stateid) or die DBI::errstr;;
    }
    print STDERR "New gameid $gameid\n";
    #$Pool::dB::dbh->do('INSERT INTO pendingshots (stateid,gameid,agentid,timesent) VALUES (?,?,?,NOW())',{},$stateid,$gameid,$agentid);
  } else {
    print STDERR "Existing shot ($gameid,$stateid)\n";
  }
  $Pool::dB::dbh->do('UPDATE pendingshots SET timesent=now(),sent_to=? WHERE stateid=? AND gameid=? AND agentid=?',{},$ENV{REMOTE_ADDR},$stateid,$gameid,$agentid) or die DBI::errstr;;
  
  my $state_info = $Pool::dB::dbh->selectrow_array('SELECT gamestate FROM encoded_gamestates WHERE stateid=?',{},$stateid) or die DBI::errstr;;
  my $noise_info = $Pool::dB::dbh->selectrow_array('SELECT get_noise(?,?)',{},$stateid,$gameid) or die DBI::errstr;;
  
  $Pool::dB::dbh->commit();
  return {shot_available => SOAP::Data->type(boolean=>1), gameid => $gameid, stateid => $stateid,
          state_info => $state_info,noise_info => $noise_info};
}

sub endgame {
  my ($gameid,$endtype,$start_player_won)=@_;
  $start_player_won=$start_player_won?1:0;
  Pool::dB::update('games','gameid',$gameid,[qw(end_reason start_player_won)],[$endtype,$start_player_won]);
}

sub submit_shot {
  shift;
  print STDERR "submit_shot: ",join('|',@_)."\n";
  #print STDERR $ENV{REMOTE_ADDR}."\n";
  my ($gameid,$agentid,$password,$stateid,$a,$b,$theta,$phi,$v,$cue_x,$cue_y,$ball,$pocket,$decision,$timeSpent) = @_;
  return "Bad password" unless authenticate_agent($agentid,$password);
  print STDERR "auth OK..\n";
  #print STDERR "TIMESPENT = $timeSpent\n";
  my ($shottime) = $Pool::dB::dbh->selectrow_array(
    'SELECT EXTRACT(EPOCH FROM NOW()-timesent) FROM pendingshots WHERE stateid=? AND gameid=? AND agentid=? AND timesent IS NOT NULL',{},
    $stateid,$gameid,$agentid) or die DBI::errstr;
  unless ($shottime) {
    return "No such shot!";
  }
  my ($faketime,$rules)=$Pool::dB::dbh->selectrow_array('SELECT faketime,rules FROM games g JOIN matches m ON g.matchid=m.matchid WHERE g.gameid=?',{},$gameid) or die DBI::errstr;;
  $timeSpent=$shottime unless $faketime;
  print STDERR "Time spent = $timeSpent faketime = $faketime\n";
  my $state_info = $Pool::dB::dbh->selectrow_array('SELECT gamestate FROM encoded_gamestates WHERE stateid=?',{},$stateid) or die DBI::errstr;;
  my ($terminal,$posreqd,$decisionallowed,$shotreqd,$cur_player_started) = $Pool::dB::dbh->selectrow_array(
    'SELECT terminal,posreqd,decisionallowed,shotreqd,cur_player_started  FROM states NATURAL JOIN turntypes WHERE stateid=?',{},$stateid) or die DBI::errstr;;
  return "Shot submitted for terminal state!" if ($terminal);
  $Pool::dB::dbh->do('DELETE FROM pendingshots WHERE gameid=? AND stateid=?',{},$gameid,$stateid) or die DBI::errstr;;
  if ($decision==4) { #Concede
    endgame($gameid,8,!$cur_player_started);
  } else {
    my $gamestate=Pool::Rules::GameState::Factory($state_info);
    my $sp = new Pool::Fiz::ShotParams($a,$b,$theta,$phi,$v);
    if ($shotreqd) {
      my $noise_info = $Pool::dB::dbh->selectrow_array('SELECT get_noise(?,?)',{},$stateid,$gameid) or die DBI::errstr;;
      my $noise=Pool::Fiz::Noise::Factory($noise_info);
      $noise->applyNoise($sp);
    }
    my $gs = new Pool::Rules::GameShot();
    $gs->{params}=$sp; $gs->{cue_x}=$cue_x; $gs->{cue_y}=$cue_y; $gs->{decision}=$decision;
    $gs->{pocket}=$pocket; $gs->{ball}=$ball; $gs->{timeSpent}=$timeSpent;
    print STDERR "Executing shot!\n";
    my $result=$gamestate->executeShot($gs);
    if ($result == $Pool::Rules::SR_BAD_PARAMS) {
      $Pool::dB::dbh->rollback(); #Fail transaction
      return "Bad shot information received!";
    } elsif ($result == $Pool::Rules::SR_SHOT_IMPOSSIBLE) {
      $Pool::dB::dbh->rollback(); #Fail transaction
      return SOAP::Data->type(boolean=>0); # Shot physically impossible
    } elsif ($result == $Pool::Rules::SR_TIMEOUT) {
      print STDERR "TIMEOUT! ".$gamestate->timeLeft()." left\n";
      endgame($gameid,3,!$cur_player_started);
    } else { # Legal shot
      my $newstate=$gamestate->addToDb();
      if ($rules == 3) {
        $Pool::dB::dbh->do('UPDATE states SET turntype=1 WHERE turntype=0 AND stateid=?',{},$newstate) or die DBI::errstr;
      }
      my @cols=qw/gameid agentid prev_state next_state timespent remote_ip/;
      my @colvals=($gameid,$agentid,$stateid,$newstate,sprintf('%.6f sec',$timeSpent),$ENV{REMOTE_ADDR});
      if ($shotreqd) {
        push @cols,qw/a b theta phi v nl_a nl_b nl_theta nl_phi nl_v/;
        push @colvals,($sp->{a},$sp->{b},$sp->{theta},$sp->{phi},$sp->{v},$a,$b,$theta,$phi,$v);
        if ($ball != $Pool::Fiz::Ball::UNKNOWN_ID) {
          push @cols,'ball'; push @colvals,$ball;
        }
        if ($pocket != $Pool::Fiz::Table::UNKNOWN_POCKET) {
          push @cols,'pocket'; push @colvals,$pocket;
        }
      }
      if ($posreqd) {
        push @cols,qw/cue_x cue_y/;
        push @colvals,($cue_x,$cue_y);
      }
      if ($decisionallowed) {
        push @cols,'decision';
        push @colvals,$decision;
      }
      $Pool::dB::dbh->do('INSERT INTO shots ('.join(',',@cols).') VALUES ('.join(',',map {'?'} @cols).');',{},@colvals) or die DBI::errstr;;
      #my $shotid=$Pool::dB::dbh->selectrow_array('SELECT lastval();');
      if (($rules == 2 || $rules == 3) && $result == $Pool::Rules::SR_OK_LOST_TURN) {
        # Lost turn in WoB test
        endgame($gameid,7,!$cur_player_started);
        $Pool::dB::dbh->do('SELECT add_to_cache(?,?)',{},$gameid,$newstate) or die DBI::errstr;;
      } else {
        my ($nextagent) = $Pool::dB::dbh->selectrow_array('SELECT get_next_agent(?,?)',{},$gameid,$newstate) or die DBI::errstr;;
        if ($nextagent) {
          $Pool::dB::dbh->do('INSERT INTO pendingshots (stateid,gameid,agentid) VALUES (?,?,?)',{},$newstate,$gameid,$nextagent) or die DBI::errstr;;
        } else {
          if ($result == $Pool::Rules::SR_OK) {
            endgame($gameid,1,$cur_player_started); # Win
          } else {
            endgame($gameid,2,!$cur_player_started); # Loss
          }
        }
      }
    }
  }
  $Pool::dB::dbh->commit();
  return SOAP::Data->type(boolean=>1); #Shot accepted
}

#print Dumper(gettestgame());
        
XMLRPC::Transport::HTTP::CGI
    ->new()
    ->dispatch_to(qw(getgame gettestgame coltitle coltext dump execshot testshot register_agent get_shot submit_shot))
#    ->options({compress_threshold=>0})
    ->handle;

