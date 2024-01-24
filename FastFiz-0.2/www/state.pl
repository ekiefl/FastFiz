#!/usr/bin/perl -wT
use strict;
use CGI qw(:standard *table -nosticky);

BEGIN
{
  push @INC,'.';
}
use Pool::dB;
use Pool::AJAX;
use HTML::DragAndDrop;

chkauth();

sub get_html {
  my $out;
  print STDERR "get_html called\n";
  if (param('stateid')) {
    my $stateid=param('stateid');
    if (check_access('state',$stateid)) {
      $out.= start_html(-title=>"State $stateid",-style=>{src=>'pool.css'},-script=>{-src=>'pool.js'});
      $out.= h1("State $stateid");
      $out.= input_form('states','stateid',$stateid,'turntype','cur_player_started',
                 'playing_solids','timeleft','timeleft_opp');
      $out.=query_table('SELECT * FROM shots WHERE prev_state=? OR next_state=?',$stateid,$stateid);
      $out.= h2("Graphic");
      my $dd = HTML::DragAndDrop->new(javascript_dir => '.');
      for my $i (0..15) {
        $dd->add_dragable(name=>"ball$i",src=>"ballimg.pl?id=$i&size=28",
                          width => 27, height => 27, left=>0, top=>0,
                          features=> 'CURSOR_HAND+MAXOFFLEFT+0+MAXOFFTOP+0+MAXOFFRIGHT+1091+MAXOFFBOTTOM+531');
      }
      #my @balls=map {img({src=>"ballimg.pl?id=$_&size=28",class=>'ball',id=>"ball$_"})} (0..15);
      #$out.= div({id=>'state',class=>'state'},join('',@balls));
      $out.= div({id=>'state',class=>'state'},$dd->output_html);
      $out.=$dd->output_script;
      $out.= '<script type="text/javascript">'.jstate($stateid).'</script>';
      $out.= h2("Balls");
      $out.= query_table('SELECT * FROM tablestates WHERE stateid=?',$stateid);
      $out.= end_html();
    } else {
      $out.= perm_err();
    }
  } else {
    $out.= start_html(-title=>'State List',-style=>{src=>'pool.css'});
    $out.= h1('State List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM states');
    } else {
      $out.= query_table('SELECT s.* FROM states s NATURAL JOIN state_access WHERE userid=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print STDERR "before ajax\n";

print Pool::AJAX::go('states','stateid',\&get_html);
