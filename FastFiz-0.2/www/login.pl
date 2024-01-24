#!/usr/bin/perl -wT
use strict;
use CGI qw/:standard/;

BEGIN
{
  push @INC,'.';
}
use Pool::dB;
use Pool::AJAX;

if ((param('confirm_password') eq param('password')) && param('username')) {
  $Pool::dB::dbh->do('INSERT INTO users (username,passwd) VALUES(?,?)',{},param('username'),param('password'));
  $Pool::dB::dbh->commit();
}

if (param('username') && auth(param('username'),param('password'))) {
  my $u=cookie('username',param('username'));
  my $p=cookie('password',param('password'));
  my $url=param('redir') || 'index.html';
  print redirect(-cookie=>[$u,$p],-url=>$url,-status=>303);
} else {
  my $u=cookie('username','');
  my $p=cookie('password','');
  print header(-cookie=>[$u,$p]);
  print start_html(-title=>'Login',-style=>{src=>'pool.css'});
  print h1('Computational Pool System');
  print start_form();
  print hidden('redir');
  print p('Username: '.textfield(-name=>'username',-size=>20));
  print p('Password: '.password_field(-name=>'password',-size=>20));
  print p('Confirm Password (new user only): '.password_field(-name=>'confirm_password',-size=>20));
  print p(submit('Login'));
  print end_form();
  print end_html();
}
