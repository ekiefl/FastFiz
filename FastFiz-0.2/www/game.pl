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
  if (param('gameid')) {
    my $gameid=param('gameid');
    if (check_access('game',$gameid)) {
      $out.= start_html(-title=>"Game $gameid",-style=>{src=>['pool.css','gwt/Pool.css']});
      $out.= h1("Game $gameid");
      $out.= p(a({href=>"logfile.pl?gameid=$gameid"},"Download log file"));
      $out.=input_form('games','gameid',$gameid,'gametype','agentid1','agentid2',
                 'start_player_won','end_reason');
      $out.= h2('Javascript!');
      my $API=getAPIURL();
      $out.= <<"EOF";
      <script type="text/javascript">
        var GameInfo = {
          gameID: "G$gameid",
          gameURL : "$API"
        };
      </script>
      <script type="text/javascript" language="javascript" src="gwt/pool/pool.nocache.js"></script>
      <div name="pooltable" id="pooltable"></div>
EOF
  #    $out.= h2('Shots');
  #    $out.= query_table('SELECT * FROM shots WHERE gameid=?',$gameid);
      $out.= end_html();
    } else {
      $out.= perm_err();
    }
  } else {
    $out.= start_html(-title=>'Game List',-style=>{src=>'pool.css'});
    $out.= h1('Game List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM games');
    } else {
      $out.= query_table('SELECT g.* FROM games g NATURAL JOIN game_access ga WHERE userid=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('games','gameid',&get_html);
