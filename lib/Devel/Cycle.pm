package Devel::Cycle;

use 5.008000;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(find_cycle);
our $VERSION = '1.00';

sub find_cycle {
  my $ref      = shift;
  my $callback = shift;
  unless ($callback) {
    my $counter = 0;
    $callback = sub {
      _do_report(++$counter,shift)
    }
  }
  _find_cycle($ref,{},$callback,());
}

sub _find_cycle {
  my $current   = shift;
  my $seenit    = shift;
  my $callback  = shift;
  my @report  = @_;

  if ($seenit->{$current}) {
    $callback->(\@report);
    return;
  }

  return unless ref $current;
  $seenit->{$current}++;

  if (UNIVERSAL::isa($current,'SCALAR') || UNIVERSAL::isa($current,'REF')) {
    _find_cycle($$current,{%$seenit},$callback,
		(@report,['SCALAR',undef,$current => $$current]));
  }

  elsif (UNIVERSAL::isa($current,'ARRAY')) {
    for (my $i=0; $i<@$current; $i++) {
      _find_cycle($current->[$i],{%$seenit},$callback,
		  (@report,['ARRAY',$i,$current => $current->[$i]]));
    }
  }
  elsif (UNIVERSAL::isa($current,'HASH')) {
    for my $key (keys %$current) {
      _find_cycle($current->{$key},{%$seenit},$callback,
		  (@report,['HASH',$key,$current => $current->{$key}]));
    }
  }
}

sub _do_report {
  my $counter = shift;
  my $path    = shift;
  print "Cycle ($counter):\n";
  foreach (@$path) {
    my ($type,$index,$ref,$value) = @$_;
    printf("\t%30s => %-30s\n",$ref,$value)               if $type eq 'SCALAR';
    printf("\t%30s => %-30s\n","${ref}->[$index]",$value) if $type eq 'ARRAY';
    printf("\t%30s => %-30s\n","${ref}->{$index}",$value) if $type eq 'HASH';
  }
  print "\n";
}

1;
__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Devel::Cycle - Find memory cycles in objects

=head1 SYNOPSIS

  #!/usr/bin/perl
  use Devel::Cycle;
  my $test = {fred   => [qw(a b c d e)],
	    ethel  => [qw(1 2 3 4 5)],
	    george => {martha => 23,
		       agnes  => 19}
	   };
  $test->{george}{phyllis} = $test;
  $test->{fred}[3]      = $test->{george};
  $test->{george}{mary} = $test->{fred};
  find_cycle($test);
  exit 0;

  # output:

 Cycle (1):
 	HASH(0x8171d30)->{george} => HASH(0x8171d00)
	HASH(0x8171d00)->{phyllis} => HASH(0x8171d30)

 Cycle (2):
	HASH(0x8171d30)->{george} => HASH(0x8171d00)
	HASH(0x8171d00)->{mary} => ARRAY(0x814be60)
	ARRAY(0x814be60)->[3] => HASH(0x8171d00)

 Cycle (3):
	HASH(0x8171d30)->{fred} => ARRAY(0x814be60)
	ARRAY(0x814be60)->[3] => HASH(0x8171d00)
	HASH(0x8171d00)->{phyllis} => HASH(0x8171d30)

 Cycle (4):
	HASH(0x8171d30)->{fred} => ARRAY(0x814be60)
	ARRAY(0x814be60)->[3] => HASH(0x8171d00)
	HASH(0x8171d00)->{mary} => ARRAY(0x814be60)

=head1 DESCRIPTION

This is a simple developer's tool for finding cycles in objects and
other types of references.  Because of Perl's reference-count based
memory management, cycles will cause memory leaks.

=head2 EXPORT

The find_cycle() subroutine is exported by default.

=over 4

=item find_cycle($object_reference,[$callback])

The find_cycle() function will traverse the object reference and print
a report to STDOUT identifying any memory cycles it finds.

If an optional callback code reference is provided, then this callback
will be invoked on each cycle that is found.  The callback will be
passed an array reference pointing to a list of lists with the
following format:

 $arg = [ ['REFTYPE',$index,$reference,$reference_value],
          ['REFTYPE',$index,$reference,$reference_value],
          ['REFTYPE',$index,$reference,$reference_value],
           ...
        ]

Each element in the array reference describes one edge in the memory
cycle.  'REFTYPE' describes the type of the reference and is one of
'SCALAR','ARRAY' or 'HASH'.  $index is the index affected by the
reference, and is undef for a scalar, an integer for an array
reference, or a hash key for a hash.  $reference is the memory
reference, and $reference_value is its dereferenced value.  For
example, if the edge is an ARRAY, then the following relationship
holds:

   $reference->[$index] eq $reference_value

The first element of the array reference is the $object_reference that
you pased to find_cycle() and may not be directly involved in the
cycle.

=back

=head1 SEE ALSO

L<Devel::Leak>

=head1 AUTHOR

Lincoln Stein, E<lt>lstein@cshl.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 by Lincoln Stein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
