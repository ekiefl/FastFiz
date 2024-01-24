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
  if (param('shotid')) {
    my $shotid=param('shotid');
    if (check_access('shot',$shotid)) {
      $out.= start_html(-title=>"Shot $shotid",-style=>{src=>['pool.css','gwt/Pool.css']});
      $out.= h1("Shot $shotid");
      my $API=getAPIURL();
      $out.= <<"EOF";
      <script type="text/javascript">
        var GameInfo = {
          gameID: "-$shotid",
          gameURL : "$API"
        };
      </script>
      <script type="text/javascript" language="javascript" src="gwt/pool/pool.nocache.js"></script>
      <div name="pooltable" id="pooltable"></div>
EOF
      $out.= h2('Data');
      $out.=input_form('shots','shotid',$shotid);
      $out.= end_html();
    } else {
      $out.=perm_err();
    }
  } else {
    $out.= start_html(-title=>'Shot List',-style=>{src=>'pool.css'});
    $out.= h1('Shot List');
    if (userid() == -1) {
      $out.= query_table('SELECT * FROM shots');
    } else {
      $out.= query_table('SELECT s.* FROM shots s NATURAL JOIN shot_access sa WHERE userid=?',userid());
    }
    $out.= end_html();
  }
  return $out;
}

print Pool::AJAX::go('shots','shotid',&get_html);
