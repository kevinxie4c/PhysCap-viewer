package MotionViewer::Joint;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $hash = shift;
    my $this = {};
    $this->{name} = $hash->{name};
    $this->{type} = $hash->{type};
    $this->{pos} = $hash->{pos};
    $this->{shape} = $hash->{shape};
    my @children;
    if (defined($hash->{children})) {
	for my $h (@{$hash->{children}}) {
	    my $j = MotionViewer::Joint->new($h);
	    push @children, $j;
	}
    }
    $this->{children} = \@children;
    bless $this, $class;
}

1;
