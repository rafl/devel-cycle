# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Devel-Cycle.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;
BEGIN { use_ok('Devel::Cycle') };

#########################

my $test = {fred   => [qw(a b c d e)],
	    ethel  => [qw(1 2 3 4 5)],
	    george => {martha => 23,
		       agnes  => 19}
	   };
$test->{george}{phyllis} = $test;
$test->{fred}[3]      = $test->{george};
$test->{george}{mary} = $test->{fred};

my ($test2,$test3);
$test2 = \$test3;
$test3 = \$test2;

my $counter = 0;
find_cycle($test,sub {$counter++});
is($counter,4,'found four cycles in $test');

$counter = 0;
find_cycle($test2,sub {$counter++});
is($counter,1,'found one cycle in $test2');


