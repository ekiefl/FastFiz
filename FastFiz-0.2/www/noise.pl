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
  if (param('noiseid')) {
    my $noiseid=param('noiseid');
    if ($noiseid eq 'new') {
      $out.=start_html(-title=>"New Noise",-style=>{src=>'pool.css'});
      $out.=h1("New Noise");
    } else {
      unless (check_access('noise',$noiseid)) {
        return perm_err();
      }
      $out.= start_html(-title=>"Noise $noiseid",-style=>{src=>'pool.css'});
      $out.= h1("Noise $noiseid");
    }
    $out.= input_form('noise','noiseid',$noiseid,
                      'noisetype','n_a','n_b','n_theta','n_phi','n_v',
                      'n_factor','known','known_opp','noisemetaid','owner','title');
    if ($noiseid ne 'new') {
      $out.= h2('Sub-noises');
      $out.= query_table('SELECT * FROM noise WHERE basenoiseid=?',$noiseid);
    }
    $out.= end_html();
  } else {
    $out.= start_html(-title=>'Noise List',-style=>{src=>'pool.css'});
    $out.= h1('Noise List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM noise');
    } else {
      $out.= query_table('SELECT n.* FROM noise n NATURAL JOIN noise_access na WHERE userid=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('noise','noiseid',\&get_html);
