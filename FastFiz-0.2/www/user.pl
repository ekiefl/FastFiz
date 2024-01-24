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
  if (param('userid')) {
    my $userid=param('userid');
    my $data;
    if ($userid eq 'new') {
      $out.=start_html(-title=>"New User",-style=>{src=>'pool.css'});
      $out.=h1("New User");
    } else {
      unless (userid() == -1) {
        return perm_err();
      }
      $out.= start_html(-title=>"User $userid",-style=>{src=>'pool.css'});
      $out.= h1("User $userid");
      $data=get_hash('SELECT * FROM users WHERE userid=?',$userid);
    }
    $out.=input_form('users','userid',$userid,'passwd','username','is_admin');
    $out.= end_html();
  } else {
    $out.= start_html(-title=>'User List',-style=>{src=>'pool.css'});
    $out.= h1('User List');
    $out.=query_table('SELECT userid,is_admin FROM users');
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('users','userid',\&get_html);
