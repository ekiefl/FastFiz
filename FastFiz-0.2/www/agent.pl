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
  if (param('agentid')) {
    my $agentid=param('agentid');
    unless (ownok('agents','agentid',$agentid)) {
      return perm_err();
    }
    $out.= start_html(-title=>"Agent $agentid",-style=>{src=>'pool.css'});
    $out.= h1("Agent $agentid");
    $out.= input_form('agents','agentid',$agentid,'agentname','cmdline','config','passwd','owner');
    $out.= h2('Matches');
    $out.= query_table('SELECT * FROM matches WHERE agentid1=? OR agentid2=?',$agentid,$agentid);
    $out.= end_html();
  } else {
   $out.= start_html(-title=>"Agent List",-style=>{src=>'pool.css'});
     $out.= h1('Agent List');
    if (userid()==-1) {
      $out.= query_table('SELECT * FROM agents');
    } else {
      $out.= query_table('SELECT * FROM agents WHERE owner=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('agents','agentid',\&get_html);
