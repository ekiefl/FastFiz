#!/usr/bin/perl -wT
use strict;
use CGI qw/:standard/;

$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX        = 1_024 * 1_024; # limit posts to 1 meg max
  
BEGIN
{
  push @INC,'.';
}

use Pool::dB;
use Pool::AJAX;

#chkauth();

print header;

$Pool::dB::dbh->do('SELECT cleanup_logfiles();') or die DBI::errstr;
$Pool::dB::dbh->commit();

if (param('upload')) {
  my $fh = upload('upload');
  if (defined($fh)) {
    print start_html(-title=>'Log File Playback',-style=>{src=>['gwt/Pool.css','pool.css']});
    my %record;
    $record{secret}=int(rand(1e6));
    while (<$fh>) {
      $record{logdata}.=$_;
    }
    my $logid=db_insert('logfiles',\%record);
    $Pool::dB::dbh->commit();
    my $API=getAPIURL();
    my $gameid="L$logid-".$record{secret};
    print <<"EOF";
    <script type="text/javascript">
      var GameInfo = {
        gameID: "$gameid",
        gameURL : "$API"
      };
    </script>
    <script type="text/javascript" language="javascript" src="gwt/pool/pool.nocache.js"></script>
    <div name="pooltable" id="pooltable"></div>
EOF
    print end_html;
  }
} else {
  print start_html(-title=>'View log file',-style=>{src=>['gwt/Pool.css','pool.css']});
  print h1('View log file');
  print start_form(-method=>'POST',-enctype=>'multipart/form-data');
  print '<p>';
  print 'Please select the log file to view: ';
  print filefield(-name=>'upload',-size=>50);
  print br(),submit(-label=>'View log');
  print '</p>';
  print end_form();
  print end_html();
}
