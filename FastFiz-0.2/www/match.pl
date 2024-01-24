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
  if (param('matchid')) {
    my $matchid=param('matchid');
    my $data;
    my $edit;
    if ($matchid eq 'new') {
      $out.=start_html(-title=>"New Match",-style=>{src=>'pool.css'});
      $out.=h1("New Match");
      $data->{owner}=realuserid();
      $edit='new';
    } else {
      unless (check_access('match',$matchid)) {
        return perm_err();
      }
      $out.= start_html(-title=>"Match $matchid",-style=>{src=>'pool.css'});
      $out.= h1("Match $matchid");
      $data=get_hash('SELECT * FROM matches WHERE matchid=?',$matchid);
      $edit='edit';
    }
    $out.= p(Pool::dB::startform('matches','matchid',$matchid));
    $out.= "<p>";
    $out.= "Match: ".colmap($edit,'title',$data);
    $out.= " (from tournament ".colmap('display','tournamentid',$data).")." if $data->{tournamentid};
    $out.= " Game: ".colmap($edit,'gametype',$data);
    $out.= " Rules: ".colmap($edit,'rules',$data);
    $out.= " Owner: ".colmap($edit,'owner',$data);
    $out.= "</p><p>";
    $out.= " Max active games: ".colmap($edit,'max_active_games',$data);
    $out.= " Priority: ".colmap($edit,'priority',$data);
    $out.= " Time Model: ".colmap($edit,'faketime',$data);
    $out.= "</p>";
    $out.= h2('Participants');
    $out.="<ul>";
    for my $i (1,2) {
      $out.="<li>";
      $out.="Agent ".colmap($edit,"agentid$i",$data);
      $out.=' with noise '.colmap($edit,"noiseid$i",$data);
      $out.=' (meta noise '.colmap($edit,"noisemetaid$i",$data).'),';
      $out.='<br/>Time limit: '.colmap($edit,"timelimit$i",$data);
      $out.='. Has '.colmap($edit,"gamesleft$i",$data).' games left to break';
      $out.="</li>";
    }
    $out.="</ul>";
    $out.= p(Pool::dB::submit($matchid eq 'new'));
    $out.= Pool::dB::endform();
#    $out.=input_form('matches','matchid',$matchid,'gametype','agentid1','agentid2',
#               'noiseid1','noiseid2','gamesleft1','gamesleft2','max_active_games',
#               'noisemetaid1','noisemetaid2','timelimit1','timelimit2','rules',
#               'title','priority');
    if ($matchid ne 'new') {
      $out.= h2('Match end histogram');
      $out.=query_table('SELECT * FROM match_endtype_histogram WHERE matchid=?',$matchid);
      $out.= h2('Games');
      $out.=query_table('SELECT * FROM games WHERE matchid=?',$matchid);
    }
    $out.= end_html();
  } else {
    $out.= start_html(-title=>'Match List',-style=>{src=>'pool.css'});
    $out.= h1('Match List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM matches');
    } else {
      $out.= query_table('SELECT m.* FROM matches m NATURAL JOIN match_access ma WHERE userid=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('matches','matchid',\&get_html);
