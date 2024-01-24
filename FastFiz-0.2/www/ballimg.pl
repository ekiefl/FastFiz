#!/usr/bin/perl -w
use strict;
use CGI qw(:standard);
use GD;
use POSIX;

print header('image/png');

my @COLORS=([255,255,255],[237,243,0],[17,10,103],[223,0,0],[122,5,119],[224,98,0],[0,111,0],[128,0,0],[0,0,0]);

my $size=param('size') || 21;

$size-- unless ($size&1);

my $im=new GD::Image($size,$size);
my $bg=$im->colorAllocate(127,127,127);
$im->transparent($bg);
my $id=param('id') || 0;
die unless ($id>=0 && $id <=15);
my $solid=($id<9);
my $color=($solid?$COLORS[$id]:$COLORS[$id-8]);
my $fg=$im->colorAllocate(@$color);
my $white=$im->colorAllocate(255,255,255);
my $black=$im->colorAllocate(0,0,0);
my $center=($size-1)/2;
$im->filledEllipse($center,$center,$size,$size,$solid?$fg:$white);
if (!$solid) {
  my $y1=($size*3/16);
  my $y2=$size-$y1;
  my $x1=$center-POSIX::floor(sqrt($size*$y1-$y1*$y1));
  my $x2=$size-$x1;
  $im->line($x1,$y1,$x2,$y1,$fg);
  $im->line($x1,$y2,$x2,$y2,$fg);
  $im->fill($center,$center,$fg);
}
$im->filledEllipse($center,$center,($size+1)/2,($size+1)/2,$white);
if ($id) {
  $id+=0;
  my $h=8;
  my $w=5;
  $w*=2 if ($id>9);
  $im->string(gdTinyFont,$center-int($w/2),$center-$h/2,$id,$black);
}
print $im->png;
