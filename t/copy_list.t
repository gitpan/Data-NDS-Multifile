#!/usr/bin/perl -w

require 5.001;

$runtests=shift(@ARGV);
if ( -f "t/test.pl" ) {
  require "t/test.pl";
  $dir="t";
} elsif ( -f "test.pl" ) {
  require "test.pl";
  $dir=".";
} else {
  die "ERROR: cannot find test.pl\n";
}

unshift(@INC,$dir);
use Data::NDS::Multifile;

sub test {
  (@test)=@_;
  my $ele = shift(@test);
  $val = $obj->value($ele,@test);
  $err = $obj->err();
  $file = $obj->ele_file($ele);

  if (ref($val) eq "HASH") {
    @val = map { $_,$$val{$_} } sort(keys %$val);
  } elsif (ref($val) eq "ARRAY") {
    @val = @$val;
  } else {
    @val = ($val);
  }
  return (@val,$err,$file);
}

$obj = new Data::NDS::Multifile;
$obj->file("FILE1","$dir/DATA.file.list.1.yaml",
           "FILE2","$dir/DATA.file.list.2.yaml");
$obj->copy_ele("0");
$obj->copy_ele("0","FILE2");

$tests = "

0 /x ~ 1 _blank_ FILE1

1 /x ~ 1 _blank_ FILE1

2 /x ~ 3 _blank_ FILE2

3 /x ~ 5 _blank_ FILE2

4 /x ~ 1 _blank_ FILE2

";


print "value...\n";
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

