package Devel::Cycle;
# $Id: Cycle.pm,v 1.6 2005/01/21 18:49:04 lstein Exp $

use 5.006001;
use strict;
use Carp 'croak';
use warnings;

use Scalar::Util qw(isweak blessed);

my $SHORT_NAME = 'A';
my %SHORT_NAMES;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(find_cycle);
our @EXPORT_OK = qw($FORMATTING);
our $VERSION = '1.03';
our $FORMATTING = 'roasted';

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

  return unless ref $current;

  # note: it seems like you could just do:
  #
  #    return if isweak($current);
  #
  # but strangely the weak flag doesn't seem to survive the copying,
  # so the test has to happen directly on the reference in the data
  # structure being scanned.

  if ($seenit->{$current}) {
    $callback->(\@report);
    return;
  }
  $seenit->{$current}++;

  my $type = _get_type($current);

  if ($type eq 'SCALAR') {
     return if isweak($current);
    _find_cycle($$current,{%$seenit},$callback,
		(@report,['SCALAR',undef,$current => $$current]));
  }

  elsif ($type eq 'ARRAY') {
    for (my $i=0; $i<@$current; $i++) {
      next if isweak($current->[$i]);
      _find_cycle($current->[$i],{%$seenit},$callback,
		  (@report,['ARRAY',$i,$current => $current->[$i]]));
    }
  }
  elsif ($type eq 'HASH') {
    for my $key (sort keys %$current) {
       next if isweak($current->{$key});
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
    printf("\t%30s => %-30s\n",_format_reference($type,$index,$ref,0),_format_reference(undef,undef,$value,1));
  }
  print "\n";
}

sub _format_reference {
  my ($type,$index,$ref,$deref) = @_;
  $type ||= _get_type($ref);
  return $ref unless $type;
  my $suffix  = defined $index ? _format_index($type,$index) : '';
  if ($FORMATTING eq 'raw') {
    return $ref.$suffix;
  }

  else {
    my $package  = blessed($ref);
    my $prefix   = $package ? ($FORMATTING eq 'roasted' ? "${package}::" : "${package}="  ) : '';
    my $sygil    = $deref ? '\\' : '';
    my $shortname = ($SHORT_NAMES{$ref} ||= $SHORT_NAME++);
    return $sygil . ($sygil ? '$' : '$$'). $prefix . $shortname . $suffix if $type eq 'SCALAR';
    return $sygil . ($sygil ? '@' : '$') . $prefix . $shortname . $suffix  if $type eq 'ARRAY';
    return $sygil . ($sygil ? '%' : '$') . $prefix . $shortname . $suffix  if $type eq 'HASH';
  }
}

sub _get_type {
  my $thingy = shift;
  return unless ref $thingy;
  return 'SCALAR' if UNIVERSAL::isa($thingy,'SCALAR') || UNIVERSAL::isa($thingy,'REF');
  return 'ARRAY'  if UNIVERSAL::isa($thingy,'ARRAY');
  return 'HASH'   if UNIVERSAL::isa($thingy,'HASH');
}

sub _format_index {
  my ($type,$index) = @_;
  return "->[$index]" if $type eq 'ARRAY';
  return "->{'$index'}" if $type eq 'HASH';
  return;
}

1;
__END__

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
	                $A->{'george'} => \%B
	               $B->{'phyllis'} => \%A

Cycle (2):
	                $A->{'george'} => \%B
	                  $B->{'mary'} => \@A
	                       $A->[3] => \%B

Cycle (3):
	                  $A->{'fred'} => \@A
	                       $A->[3] => \%B
	               $B->{'phyllis'} => \%A

Cycle (4):
	                  $A->{'fred'} => \@A
	                       $A->[3] => \%B
	                  $B->{'mary'} => \@A

=head1 DESCRIPTION

This is a simple developer's tool for finding circular references in
objects and other types of references.  Because of Perl's
reference-count based memory management, circular references will
cause memory leaks.

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

If a reference is a weak ref produced using Scalar::Util's weaken()
function then it won't contribute to cycles.

=back

The default callback prints out a trace of each cycle it finds.  You
can control the format of the trace by setting the package variable
$Devel::Cycle::FORMATTING to one of "raw," "cooked," or "roasted."

The "raw" format prints out anonymous memory references using standard
Perl memory location nomenclature.  For example, a "Foo::Bar" object
that points to an ordinary hash will appear in the trace like this:

	Foo::Bar=HASH(0x8124394)->{'phyllis'} => HASH(0x81b4a90)

The "cooked" format (the default), uses short names for anonymous
memory locations, beginning with "A" and moving upward with the magic
++ operator.  This leads to a much more readable display:

        $Foo::Bar=B->{'phyllis'} => \%A

The "roasted" format is similar to the "cooked" format, except that
object references are formatted slightly differently:

	$Foo::Bar::B->{'phyllis'} => \%A

For your convenience, $Devel::Cycle::FORMATTING can be imported:

       use Devel::Cycle qw(:DEFAULT $FORMATTING);
       $FORMATTING = 'raw';


=head1 SEE ALSO

L<Devel::Leak>

L<Scalar::Util>

=head1 AUTHOR

Lincoln Stein, E<lt>lstein@cshl.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 by Lincoln Stein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
