#!/usr/bin/perl -wT
use strict;
use CGI qw/:standard/;

BEGIN
{
  push @INC,'.';
}
use Pool::dB;
use Pool::AJAX;

chkauth();

sub get_html {
  my $out;
  if (param('tournamentid')) {
    my $tournamentid=param('tournamentid');
    my $data;
    my $edit;
    if ($tournamentid eq 'new') {
      $out.=start_html(-title=>"New Tournament",-style=>{src=>'pool.css'});
      $out.=h1("New Tournament");
      $data->{owner}=realuserid();
#      $data->{rules}=1;
#      $data->{priority}=0;
#      $data->{max_active_games}=5;
      $edit='new';
    } else {
      unless (ownok('tournaments','tournamentid',$tournamentid)) {
        return perm_err();
      }
      $out.= start_html(-title=>"Tournament $tournamentid",-style=>{src=>'pool.css'},-script=>{-src=>'pool.js'});
      $out.= h1("Tournament $tournamentid");
      $data=get_hash('SELECT * FROM tournaments WHERE tournamentid=?',$tournamentid);
      $edit='edit';
    }
    $out.= p(Pool::dB::startform('tournaments','tournamentid',$tournamentid));
    $out.= "<p>";
    $out.= "Tournament: ".colmap($edit,'title',$data);
    $out.= " Game: ".colmap($edit,'gametype',$data);
    $out.= " Rules: ".colmap($edit,'rules',$data);
    $out.= " Owner: ".colmap($edit,'owner',$data);
    $out.= "</p><p>";
    $out.= "Master Agent: ".colmap($edit,'master_agent',$data);
    $out.="</p><p>";
    $out.= " Max games: ".colmap($edit,'max_games',$data);
    $out.= " Max active games: ".colmap($edit,'max_active_games',$data);
    $out.= " Priority: ".colmap($edit,'priority',$data);
    $out.= " Time Model: ".colmap($edit,'faketime',$data);
    $out.= "</p>";
    $out.= p(Pool::dB::submit($tournamentid eq 'new'));
#    $out.=input_form('tournaments','tournamentid',$tournamentid,'gametype','agentid1','agentid2',
#               'noiseid1','noiseid2','gamesleft1','gamesleft2','max_active_games',
#               'noisemetaid1','noisemetaid2','timelimit1','timelimit2','rules',
#               'title','priority');
    if ($tournamentid ne 'new') {
      $out.= h2('Paricipants');
      my ($started)=$Pool::dB::dbh->selectrow_array('SELECT EXISTS(SELECT matchid FROM matches WHERE tournamentid=?)',{},$tournamentid);
      if ($started) {
        $out.=query_table('SELECT agentid,timelimit,noiseid,noisemetaid FROM tournament_agents WHERE tournamentid=?',$tournamentid);
      } else {
        my $add=Tr(map {td(colmap('add',$_))} qw/agentid timelimit noiseid noisemetaid add/);
        $out.=query_table2($add,'SELECT agentid,timelimit,noiseid,noisemetaid,agentid as "delete" FROM tournament_agents WHERE tournamentid=?',$tournamentid);
        $out.=p(CGI::submit(-name=>'start',-value=>'Start Tournament'));
      }
      $out.= h2('Matches');
      $out.=query_table('SELECT * FROM matches WHERE tournamentid=?',$tournamentid);
    }
    $out.= Pool::dB::endform();
    $out.= end_html();
  } else {
    $out.= start_html(-title=>'Tournament List',-style=>{src=>'pool.css'});
    $out.= h1('Tournament List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM tournaments');
    } else {
      $out.= query_table('SELECT * FROM tournaments WHERE owner=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('tournaments','tournamentid',\&get_html);
