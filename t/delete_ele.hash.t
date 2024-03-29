#!/usr/bin/perl -w

require 5.001;

$runtests=shift(@ARGV);
if ( -f "t/test.pl" ) {
  require "t/test.pl";
  $dir="./lib";
  $tdir="t";
} elsif ( -f "test.pl" ) {
  require "test.pl";
  $dir="../lib";
  $tdir=".";
} else {
  die "ERROR: cannot find test.pl\n";
}

unshift(@INC,$dir);
use Data::NDS::Multifile;

sub test {
  (@test)=@_;
  @ele = $obj->eles();
  $obj->delete_ele(@test);
  @el2 = $obj->eles();
  return (@ele,'--',@el2);
}

$obj = new Data::NDS::Multifile;
$obj->file("FILE1","$tdir/DATA.file.hash.1.yaml",
           "FILE2","$tdir/DATA.file.hash.2.yaml");

$tests = "
a ~ a b c -- b c

";

print "delete_ele (hash)...\n";
test_Func(\&test,$tests,$runtests);

1;
# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 3
# cperl-continued-statement-offset: 2
# cperl-continued-brace-offset: 0
# cperl-brace-offset: 0
# cperl-brace-imaginary-offset: 0
# cperl-label-offset: -2
# End:

