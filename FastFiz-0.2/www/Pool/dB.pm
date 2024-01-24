package Pool::dB;
use strict;

BEGIN{
  push @INC,"../FastFiz/perl";
}

use Pool;
use DBI;
use Exporter;
use CGI qw(:standard *table -nosticky);
use URI::Escape;

our @EXPORT = qw(query_table query_table2 jstate input_form colmap colname get_hash update auth chkauth userid realuserid ownok perm_err check_access db_insert);
our @ISA = qw(Exporter);

#my $database=do "../database/config.pl" or die "Bad config - $!\n";

my ($DB_NAME,$DB_HOST,$DB_USER,$DB_PASSWORD);
#  =($database->{name},$database->{host},$database->{user},$database->{password});

open(CONFIG,"../database/config.mk") or die "Bad config - $!\n";
while (<CONFIG>) {
  if (/^DATABASE=(.+)$/) {
    $DB_NAME=$1;
  } elsif (/^USER=(.+)$/) {
    $DB_USER=$1;
  } elsif (/^HOST=(.+)$/) {
    $DB_HOST=$1;
  } elsif (/^PASSWORD=(.+)$/) {
    $DB_PASSWORD=$1;
  }
}
close (CONFIG);


our $dbh=DBI->connect("dbi:Pg:database=$DB_NAME;host=$DB_HOST",$DB_USER,$DB_PASSWORD,{AutoCommit => 0}) or die $DBI::errstr;
our ($userid,$realuserid);

my %MAP_CACHE;

sub get_map {
  my $key=shift;
  my $table=shift;
  my $val=shift;
  my $id=shift;
  unless ($MAP_CACHE{"$table/$val"}) {
    $MAP_CACHE{"$table/$val"}=$dbh->selectall_hashref("SELECT $key AS key,$val AS val FROM $table",'key');
  }
  if (defined($id)) {
    my $ret=$MAP_CACHE{"$table/$val"}{$id}{val};
    return $ret if defined($ret);
    return $id;
  }
}

our %MAPS = ('matchid'=>{title=>'Match',table=>'matches',value=>'title',script=>'match.pl',auth=>'match_access'},
             'tournamentid'=>{title=>'Tournament',table=>'tournaments',value=>'title',script=>'tournament.pl',auth=>'owner'},
             'gameid'=>{title=>'Game',table=>'games',script=>'game.pl',auth=>'game_access'},
             'shotid'=>{title=>'Shot',table=>'shots',script=>'shot.pl',auth=>'shot_access'},
             'rulesid'=>{title=>'Rules',table=>'rules',edittype=>'select',value=>'description',auth=>'none',default=>1},
             'rules'=>{type=>'rulesid'},
             'gametype'=>{title=>'Game Type',table=>'gametypes',value=>'description',edittype=>'select',auth=>'none',default=>1},
             'agentid'=>{title=>'Agent',table=>'agents',value=>q{agentname || ' (' || config || ')'},script=>'agent.pl',edittype=>'select',auth=>'owner',nullval=>'(None)'},
             'opp_agentid'=>{title=>'Opponent',type=>'agentid'},
             'master_agent'=>{title=>'Master Agent',type=>'agentid',nullval=>'None'},
             'agent'=>{type=>'agentid'},
             'owner'=>{title=>'Owner',type=>'userid'},
             'userid'=>{table=>'users',value=>q{username},script=>'user.pl',edittype=>'select',
                        nullval=>'no owner',auth=>'none'},
             'noiseid'=>{title=>'Noise',table=>'noise',script=>'noise.pl',
                         value=>q{CASE WHEN noisetype = 2 THEN n_factor || 'x' || n_a || '/' || n_b || '/' || n_theta||'/'||n_phi||'/'||n_v ELSE coalesce(title,noiseid::text) END},
                         editvalue=>q{CASE WHEN noisetype = 2 THEN n_factor || 'x' || n_a || '/' || n_b || '/' || n_theta||'/'||n_phi||'/'||n_v ELSE CASE WHEN noisetype=1 THEN '0' ELSE noiseid::text END END},
                         auth=>'noise_access',default=>1},
             'noisemetaid'=>{title=>'Meta Noise',table=>'noisemeta',script=>'noisemeta.pl',value=>'title',edittype=>'select',
                         nullval=>'None',auth=>'none',default=>0},
             'end_reason'=>{title=>'End Reason',table=>'end_reasons',value=>'description',edittype=>'select',
                            nullval=>'Not Ended',auth=>'none'},
             'noisetype'=>{title=>'Noise Type',table=>'noisetypes',value=>'description',edittype=>'select',auth=>'none',default=>2},
             'turntype'=>{title=>'Turn Type',table=>'turntypes',value=>'description',edittype=>'select',auth=>'none'},
             'status'=>{title=>'State',table=>'ballstates',value=>'description',edittype=>'select',auth=>'none'},
             'stateid'=>{title=>'State',table=>'states',script=>'state.pl'},
             'prev_state'=>{title=>'Previous State',type=>'stateid'},
             'next_state'=>{title=>'Next State',type=>'stateid'},
             'start_state'=>{title=>'Start State',type=>'stateid'},
             'is_admin'=>{title=>'Administrator',special=>'bool',trueval=>'Yes',falseval=>'No'},
             'start_player_won'=>{title=>'Winner',trueval=>'Start P.',
                                  falseval=>'Other P.',nullval=>'None',
                                  special=>'bool'},
             'faketime'=>{title=>'Time',falseval=>'Real Time',
                                  trueval=>'Fake Time',
                                  special=>'bool'},
             'cur_player_started'=>{title=>'Player',trueval=>'Start',
                                    falseval=>'Other',special=>'bool'},
             'playing_solids'=>{title=>'Side',trueval=>'Solids',
                                falseval=>'Stripes',nullval=>'Open Table',
                                special=>'bool'},
             'priority'=>{title=>'Priority',size=>2,default=>0},
             'max_games'=>{title=>'Max games',size=>2},
             'max_active_games'=>{title=>'Max active games',size=>3,default=>5},
             'timelimit'=>{title=>'Time Limit',size=>6,default=>'10 min'},
             'gamesleft'=>{title=>'Games left',size=>2},
             'delete'=>{title=>'Add/Delete',special=>'delete'},
             'add'=>{special=>'add'},
             'known'=>{title=>'Own noise',special=>'bool',trueval=>'Known',falseval=>'Unknown',default=>1},
             'known_opp'=>{title=>'Opponent noise',type=>'known',default=>1},
             'n_a'=>{default=>0.5},
             'n_b'=>{default=>0.5},
             'n_theta'=>{default=>0.1},
             'n_phi'=>{default=>0.125},
             'n_v'=>{default=>0.075},
             'n_factor'=>{default=>1},
             );

sub colname {
  return colmap('title',@_);
}

sub colmap {
  my $maptype=shift;
  my $col=shift;
  my $id;
  if (@_>0) {
    $id=shift;
  }
  if (ref($id) eq 'HASH') {
    $id=$id->{$col};
  }
  my $extra='';
  if ($col =~ /^(.+)(\d+)$/) {
    $col=$1;
    $extra=$2;
  }
  my %cmap=($MAPS{$col}?%{$MAPS{$col}}:());
  if ($cmap{type}) {
    %cmap=(%{$MAPS{$cmap{type}}},%cmap);
  }
  my $type=$cmap{type}||$col;
  my $out;
  if ($maptype eq 'display' or $maptype eq 'text' or $maptype eq 'text_auth') {
    if ($cmap{special} && $cmap{special} eq 'delete') {
      $out.=button(-name=>'delete',-value=>'Delete',-onclick=>
      "ajax_delete(['key','args__$id','NO_CACHE'],[delrow])");
    } elsif ($cmap{special} && $cmap{special} eq 'bool') {
      $out=(defined($id)?
              $id? $cmap{trueval}  || $id
                 : $cmap{falseval} || $id
             :$cmap{nullval} || '');
    } elsif (defined($id)) {
      $out=$id;
      if ($cmap{value}) {
        unless ($maptype eq 'text_auth' &&
                 userid() != -1 && 
                 (!defined($cmap{auth}) ||
                   ($cmap{auth} ne 'none' &&
                     ($cmap{auth} eq 'owner'? !ownok($cmap{table},$type,$id)
                                            : !check_access($cmap{auth},$id,$type)
                     )
                   )
                 )
               ) {
          $out=get_map($type,$cmap{table},$cmap{value},$id);
        }
      }
      if ($maptype eq 'display' and $cmap{script}) {
        $out=a({href=>$cmap{script}."?$type=$id"},$out);
      }
    }
  } elsif ($maptype eq 'title') {
    $out=$cmap{title} || $col;
    $out.=" $extra" if $extra;
  } elsif ($maptype eq 'edit' || $maptype eq 'add' || $maptype eq 'new') {
    if (defined($cmap{default}) && $maptype ne 'edit') {
      $id=$cmap{default};
    }
    my $name=($maptype eq 'add'?"add_$col$extra":"db_$col$extra");
    my $changescript=($maptype eq 'edit'?
        "submit_change(['key','args__$col$extra','db_$col$extra','NO_CACHE'],['output'])":
        '');
    if ($cmap{special} && $cmap{special} eq 'add') {
      $out.=CGI::submit(-name=>'add',-value=>'Add');
    } elsif ($cmap{special} && $cmap{special} eq 'bool') {
      my %lblhash;
      $lblhash{0}=$cmap{falseval};
      $lblhash{1}=$cmap{trueval};
      $lblhash{'*NULL*'}=$cmap{nullval};
      my @val=(0,1);
      unshift @val,'*NULL*' if (exists($cmap{nullval}));
      $out=popup_menu(-name=>$name,-values=>\@val,
                      -default=>$id,-labels=>\%lblhash,-override=>1,
                      -onchange=>$changescript);
    } elsif ($cmap{editvalue}) {
      my $size=$cmap{size} || 20;
      $out=textfield(-name=>$name,-value=>get_map($type,$cmap{table},$cmap{editvalue},$id),-size=>$size,-override=>1);
    } elsif ($cmap{edittype} && ($cmap{edittype} eq 'select')) {
      get_map($type,$cmap{table},$cmap{value},$id);
      ## DATA LEAK IF USER UNAUTHORIZED
      my %map=%{$MAP_CACHE{$cmap{table}."/".$cmap{value}}};
      while (my ($k,$v) = each %map) {
        $map{$k}=$v->{val};
      }
      $map{'*NULL*'} = $cmap{nullval} if (exists($cmap{nullval}));
      my @val=sort {$map{$a} cmp $map{$b}} (keys %map);
      unless (defined($id)) {
        $id = '*NULL*';
      }
      $out=popup_menu(-name=>$name,-default=>$id,-values=>\@val,-labels=>\%map,-override=>1,
                      -onchange=>$changescript);
    } else {
      my $size=$cmap{size} || 20;
      $out=textfield(-name=>$name,-value=>$id,-size=>$size,-override=>1);
    }
  } elsif ($maptype eq 'reverse') {
    if ($cmap{table} eq 'noise') {
      my %noise;
      if ($id =~ m{^\s*([\d\.]+)\s*x\s*([\d\.]+)\s*/\s*([\d\.]+)\s*/\s*([\d\.]+)\s*/\s*([\d\.]+)\s*/\s*([\d\.]+)\s*$}) {
        @noise{qw/n_factor n_a n_b n_theta n_phi n_v noisetype owner/}=($1,$2,$3,$4,$5,$6,2,realuserid());
        $out=$dbh->selectrow_array('SELECT noiseid FROM noise WHERE n_factor=? AND n_a=? AND n_b=? AND n_theta=? AND n_phi=? AND n_v=? AND noisetype=?',{},
           @noise{qw/n_factor n_a n_b n_theta n_phi n_v noisetype/});
      } elsif ($id eq 0) {
        @noise{qw/noisetype owner title/} = (1,realuserid(),'Noiseless');
        $out=$dbh->selectrow_array('SELECT noiseid FROM noise WHERE noisetype=?',{},$noise{noisetype});
      }
      if (!defined($out) && %noise) {
        print STDERR "ADDING!\n";
        $out=db_insert('noise',\%noise);
      }
      print STDERR "out=$out\n";
    } else {
      $out=$id;
    }
  } else {
    $out = $id;
  }
  if ($cmap{dispfunc}) {
    $out = &{$cmap{dispfunc}}($maptype,$col,$id,$extra,$out);
  }
  return $out;
}

sub query_table {
  query_table2('',@_);
}

sub query_table2 {
  my $add=shift;
  my $query=shift;
  my $out;
  my $sth=$dbh->prepare_cached($query,{},1);
  $sth->execute(@_);
  my @cols=@{$sth->{NAME}};
  my $header=join('',map {th(colname($_))} @cols);
  $out.= start_table({class=>'query'});
  $out.= Tr($header);
  my $rowcolor=1;
  while (my $data=$sth->fetchrow_hashref()) {
    $rowcolor=!$rowcolor;
    my @row=map {td(colmap('display',$_,$data->{$_}))} @cols;
    my $name;
    if ($data->{delete}) {
      $name='row'.$data->{delete};
    }
    $out.= Tr({id=>$name,class=>"row$rowcolor"},join('',@row));
  }
  $sth->finish();
  $out.= $add;
  $out.= end_table();
  return $out;
}

sub get_hash {
  my $query=shift;
  my $sth=$dbh->prepare_cached($query,{},1);
  $sth->execute(@_);
  my $data=$sth->fetchrow_hashref();
  $sth->finish();
  return $data;
}

sub input_form {
  my $table=shift;
  my $key=shift;
  my $val=shift;
  my %editable;
  @editable{@_} = (1) x @_;
  my $out;
  my $data;
  if ($val ne 'new') {
    $data=get_hash("SELECT * FROM $table WHERE $key=?",$val);
    return unless $data;
  } else {
#    $data=get_hash("SELECT * FROM $table LIMIT 0",$val);
    @{$data}{keys %editable}=('') x @_;
    $data->{owner}=realuserid();
  }
  my @cols=keys %$data;
  $out.= startform($table,$key,$val);
  $out.= start_table({class=>'input'});
  for my $c (@cols) {
    my $row=th(colname($c));
    if ($editable{$c}) {
      $row.=td(colmap($val eq 'new'?'new':'edit',$c,$data->{$c}));
    } else {
      $row.=td(colmap('display',$c,$data->{$c}));
    }
    $out.= Tr($row);
  }
  $out.= Tr(td({colspan=>2, align=>'center'}, submit($val eq 'new')));
  $out.= end_table();
  $out.= endform();
  return $out;
}

no warnings 'redefine';
sub startform {
  my ($table,$key,$val)=@_;
  return start_form(-method=>'POST').hidden($key,$val).hidden('key',$val).hidden('table',$table);
}

sub endform {
  return '<div id="output"></div>'.end_form();
}


sub submit {
  my $new=shift;
  if ($new) { 
    return CGI::submit(-name=>'insert',-value=>'Add')
  } else {
    return CGI::submit(-name=>'edit',-value=>'Submit Changes')
  }
}

use warnings;

sub jstate {
  my $state=shift;
  my $sth=$dbh->prepare_cached('SELECT ball,status,x,y FROM tablestates WHERE stateid=?',{},1);
  my $out='';
  $sth->execute($state);
  my $oopcount=0;
  while (my $data=$sth->fetchrow_hashref()) {
    my $inplay=get_map('status','ballstates','on_table',$data->{status});
    if ($inplay) {
      $out.='putBall('.$data->{ball}.','.$data->{x}.','.$data->{"y"}.");\n";
    } else {
      $out.='putOOPBall('.$data->{ball}.','.++$oopcount.");\n";
    }
  }
  $sth->finish();
  return $out;
}

sub db_insert {
  my $table=shift;
  my $record=shift;
  my $noret=shift;
  my $statement="INSERT INTO $table (".join(',',keys %$record).") VALUES (".join(',',map {'?'} keys %$record).");";
  my $sth=$dbh->prepare_cached($statement,{},1);
  $sth->execute(values %$record) or die "$statement\n".$DBI::errstr;
  $sth->finish();
  print STDERR "$statement<br/>".join('|',values %$record);  
  return 1 if ($noret);
  return $Pool::dB::dbh->selectrow_array('SELECT lastval()');
}

sub update {
  my $table=shift;
  my $key=shift;
  my $val=shift;
  my $cols=shift;
  my $vals=shift;
  $key = [$key] unless (ref($key));
  $val = [$val] unless (ref($val));
  $cols = [$cols] unless (ref($cols));
  $vals = [$vals] unless (ref($vals));
  push @$vals, @$val;
  my $statement="UPDATE $table SET ".join(',',map {"$_=?"} @$cols)." WHERE ".join(' AND ',map {"$_=?"} @$key);
  my $sth=$dbh->prepare_cached($statement,{},1);
  $sth->execute(@$vals) or die "$statement\n".join('|',@$vals)."\n".$DBI::errstr;
  $sth->finish();
  return "$statement<br/>".join('|',@$vals);
}

sub auth {
  my $username=shift || cookie('username') || url_param('username');
  my $password=shift || cookie('password') || url_param('password');
  my $admin;
  ($userid,$admin)=$Pool::dB::dbh->selectrow_array('SELECT userid,is_admin FROM users WHERE username=? AND passwd=?',{},$username,$password);
  $realuserid=$userid;
  if ($admin) {
    $userid=-1;
  }
  return $userid;
}

sub userid {
  if (!$userid) {
    return auth(@_);
  }
  return $userid;
}

sub realuserid {
  if (!$realuserid) {
    auth(@_);
  }
  return $realuserid;
}

sub chkauth() {
  if (!userid()) {
    print redirect(-url=>'login.pl?redir='.uri_escape(self_url()),-status=>303);
    exit(0);
  }
}

sub ownok {
  my ($table,$key,$val)=@_;
  return 1 if (userid() == -1);
  my ($ret)=$dbh->selectrow_array("SELECT 1 FROM $table WHERE $key=? AND \"owner\"=?",{},$val,$userid);
  return $ret;
}

sub perm_err {
  my $out;
  $out.=start_html();
  $out.=p('Permission Denied.');
  $out.=end_html();
  return $out;
}

sub check_access {
  my ($table,$val,$key) = @_;
  return 1 if (userid() == -1);
  unless ($key) {
    $key="${table}id";
    $table="${table}_access";
  }
  print STDERR  "SELECT 1 FROM $table WHERE $key=? AND userid=? $val $userid\n";
  my ($ret)=$dbh->selectrow_array("SELECT 1 FROM $table WHERE $key=? AND userid=?",{},$val,$userid);
  print STDERR "ret = $ret\n";
  return $ret;
}

package Pool::Fiz::TableState;

#Add a state's ball location information to the database
sub addToDb {
  my $self=shift;
  my $stateid=shift;
  for my $i (0..15) {
    my $ball=$self->getBall($i);
    my $state=$ball->getState();
    my $pos=$ball->getPos();
    my $x=$pos->swig_x_get();
    my $y=$pos->swig_y_get();
    my $sth=$Pool::dB::dbh->prepare_cached('INSERT INTO tablestates VALUES (?,?,?,?,?);');
    $sth->execute($stateid,$i,$state,$x,$y) or die $DBI::errstr;
  }
}

sub fromDb {
  my $self=shift;
  my $stateid=shift;
  my $sth=$Pool::dB::dbh->prepare_cached('SELECT ball,status,x,y FROM tablestates WHERE stateid=?');
  $sth->execute($stateid);
  while (my $data=$sth->fetchrow_hashref()) {
    $self->setBall($data->{ball},$data->{status},$data->{x},$data->{'y'});
  }
  return $self;
}

package Pool::Rules::GameState;

sub addToDb {
  my $self=shift;
  my $timeleft=shift || $self->timeLeft();
  my $timeleft_opp=shift || $self->timeLeftOpp();
  my $playingSolids = ($self->isOpenTable() ? undef : ($self->playingSolids()?1:0));
  print STDERR "addToDb: X".$self->isOpenTable()."X Y".$self->playingSolids()."Y Z".$playingSolids."Z\n";
  $Pool::dB::dbh->do('INSERT INTO states (turntype,cur_player_started,playing_solids,timeleft,timeleft_opp,gametype) VALUES (?,?,?,?,?,?)',{},
                     $self->getTurnType(),$self->curPlayerStarted()?1:0,$playingSolids,$timeleft,$timeleft_opp,$self->gameType()) or STDERR $DBI::errstr;
  my $stateid=$Pool::dB::dbh->selectrow_array('SELECT lastval()');
  $self->tableState()->addToDb($stateid);
  return $stateid;
}

1;