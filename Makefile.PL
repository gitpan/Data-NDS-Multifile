
use ExtUtils::MakeMaker;
use 5.001;
use strict;
use warnings;
my %requires = (
                 'Data::NDS'                => '0',
                 'Data::NDS::Multiele'      => '0',
                 'Storable'                 => '0',
                 'YAML::Syck'               => '0',
                 'Test::More'               => '0',
                 'Test::Pod'                => '0',
                 'Test::Pod::Coverage'      => '0',
               );


WriteMakefile(
        NAME             => 'Data::NDS::Multifile',
        VERSION          => '3.12',
        ($] >= 5.001
        ? (ABSTRACT=>'A multi-file version of Data::NDS::Multiele',
           AUTHOR  =>'Sullivan Beck (sbeck@cpan.org)')
        : ()),
        'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'},
        PL_FILES  => {},
        PREREQ_PM => \%requires,
);
