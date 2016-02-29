#!/usr/bin/perl
# merge old arp cache data into mysql table
require "netmap.ph";
use Getopt::Long;
use Data::Dumper;
use Date::Format;

GetOptions('test' => \$test, 'd' => \$debug, 'i' => \$interact, 'quiet' => \$quiet);

use Mysql;
if ($test) {
  $db = 'netmap_development';
  $dbhost = 'localhost';
  $dbuser = 'root';
  $dbpw = '';
  use Data::Dumper;
}
else {
  $db = 'netmap_production';
  $dbhost = 'netmap.mcmaster.ca';
  $dbpw = 'nutbar';
  $dbuser = 'netmap';
}

$DBH = Mysql->connect($dbhost,$db,$dbuser,$dbpw);

unless ($DBH) {
  print STDERR "Could not connect to database. Aborting...\n";
  exit();
}

while (<>) {
  chomp;
  ($ip,$time,$router,$if,$mac) = split(/:/, $_);
  $timestr = time2str('%Y-%m-%d %H:%M:%S',$time);
  $row = getRow($DBH,'*','arpcaches',"ip='$ip' and mac='$mac' and updated_on >= '$timestr'");
  if (!$row->{ip}) {
    $row->{ip} = $ip;
    $row->{mac} = $mac;
    $row->{router} = $router;
    $row->{if} = $if;
    $row->{updated_on} = $timestr;
    if (!updateTable($DBH,'arpcaches',"ip='$ip' and mac='$mac'",$row)) {
      print "Problem updating/inserting $ip <$mac>\n";
    }
  }
}
