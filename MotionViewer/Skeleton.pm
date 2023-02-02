package MotionViewer::Skeleton;

use File::Slurp;
use JSON;
use strict;
use warnings;

sub load {
    my $class = shift;
    my $fn = shift;
    my $hash = decode_json(read_file($fn));
    my $root = MotionViewer::Joint->new($hash);
    my $this = {
	root => $root,
    };
    bless $this, $class;
}

sub root {
    shift->{root};
}

sub joints {
    my $this = shift;
    ($this->root, $this->root->descendants);
}

sub set_positions {
    my $this = shift;
    if (@_) {
	for my $j ($this->joints) {
	    $j->positions(splice(@_, 0, $j->dof));
	}
    }
}

sub shader {
    my $this = shift;
    if (@_) {
	my $shader = shift;
	$this->{shader} = $shader;;
	for my $j ($this->joints) {
	    $j->shader($shader);
	}
    }
    $this->{shader};
}

my $identity_mat = GLM::Mat4->new(
    1, 0, 0, 0, 
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
);

sub draw {
    my $this = shift;
    my $model_matrix = GLM::Mat4->new($identity_mat);
    $this->root->draw($model_matrix);
    #my @vertices = MotionViewer::Joint::create_box(0, 0, 0, 0.1, 0.1, 0.1);
    #my $buffer= MotionViewer::Buffer->new(2, \@vertices);
    #$this->shader->set_mat4('model', $model_matrix);
    #$buffer->bind;
    #use GLM;
    #use OpenGL::Modern qw(:all);
    #glDrawArrays(GL_TRIANGLES, 0, $buffer->num_vert);
}


package MotionViewer::Joint;
use Carp;
use GLM;
use OpenGL::Modern qw(:all);
use strict;
use warnings;

use constant EPS => 1e-8;

sub new {
    my $class = shift;
    my $hash = shift;
    my $this = {};
    $this->{name} = $hash->{name};
    $this->{type} = $hash->{type};
    $this->{pos} = $hash->{pos};
    if ($hash->{shape}) {
	my @vertices = make_shape($hash->{shape});
	$this->{shape_buffer} = MotionViewer::Buffer->new(2, \@vertices);
    } else {
	$this->{shape_buffer} = undef;
    }
    my @children;
    if (defined($hash->{children})) {
	for my $h (@{$hash->{children}}) {
	    my $j = MotionViewer::Joint->new($h);
	    push @children, $j;
	}
    }
    $this->{children} = \@children;
    $this->{dof} = 0;
    my $type = $hash->{type};
    if ($type eq 'free') {
	$this->{dof} = 6
    } elsif ($type eq 'ball') {
	$this->{dof} = 3;
    } else {
	croak "unknown type: $type";
    }
    my @p = (0) x $this->{dof};
    $this->{positions} = \@p;
    bless $this, $class;
}

sub name {
    shift->{name};
}

sub type {
    shift->{type};
}

sub pos {
    @{shift->{pos}};
}

sub shape_buffer {
    shift->{shape_buffer};
}

sub dof {
    shift->{dof};
}

sub children {
    @{shift->{children}};
}

sub descendants {
    my $this = shift;
    my @list;
    for my $c ($this->children) {
        push @list, $c;
        push @list, $c->descendants;
    }
    @list;
}

sub positions {
    my $this = shift;
    if (@_) {
	$this->{positions} = [@_];
    }
    @{$this->{positions}};
}

sub shader {
    my $this = shift;
    $this->{shader} = shift if @_;
    $this->{shader};
}

sub draw {
    my ($this, $model_matrix) = @_;
    my $offset = GLM::Vec3->new($this->pos);
    $model_matrix = GLM::Functions::translate($model_matrix, $offset);
    my $type = $this->type;
    my @positions = $this->positions;
    if ($type eq 'free') {
        my $r = GLM::Vec3->new(@positions[0 .. 2]);
        my $t = GLM::Vec3->new(@positions[3 .. 5]);
	$model_matrix = GLM::Functions::translate($model_matrix, $t);
	if ($r->length >= EPS) {
	    $model_matrix = GLM::Functions::rotate($model_matrix, $r->length, $r->normalized);
	}
    } elsif ($type eq 'ball') {
        my $r = GLM::Vec3->new(@positions);
	if ($r->length >= EPS) {
	    $model_matrix = GLM::Functions::rotate($model_matrix, $r->length, $r->normalized);
	}
    } else {
        croak "unknown type: $type";
    }
    $this->shader->set_mat4('model', $model_matrix);
    if (defined($this->shape_buffer)) {
	$this->shape_buffer->bind;
        glDrawArrays(GL_TRIANGLES, 0, $this->shape_buffer->num_vert);
    }
    for my $j ($this->children) {
        $j->draw($model_matrix);
    }
}

#   a                e
#    +--------------+
#    |\              \
#    | \ d            \ h
#    |  +--------------+
#    |  |              |
#    +  |           +  |
#   b \ |          f   |
#      \|              |
#       +--------------+
#      c                g
#       
#    z  |
#       |  x
#       +----
#        \
#      y  \
sub create_box {
    my @vertices;

    my ($px, $py, $pz, $wx, $wy, $wz) = @_;
    my ($dx, $dy, $dz) = ($wx / 2, $wy / 2, $wz / 2);

    my (@a, @b, @c, @d, @e, @f, @g, @h);
    @a = ($px - $dx, $py - $dy, $pz + $dz);
    @b = ($px - $dx, $py - $dy, $pz - $dz);
    @c = ($px - $dx, $py + $dy, $pz - $dz);
    @d = ($px - $dx, $py + $dy, $pz + $dz);
    @e = ($px + $dx, $py - $dy, $pz + $dz);
    @f = ($px + $dx, $py - $dy, $pz - $dz);
    @g = ($px + $dx, $py + $dy, $pz - $dz);
    @h = ($px + $dx, $py + $dy, $pz + $dz);

    my @n1 = (-1, 0, 0);
    push @vertices, @a, @n1, @b, @n1, @c, @n1;
    push @vertices, @c, @n1, @d, @n1, @a, @n1;

    my @n2 = (1, 0, 0);
    push @vertices, @g, @n2, @f, @n2, @e, @n2;
    push @vertices, @e, @n2, @h, @n2, @g, @n2;

    my @n3 = (0, 1, 0);
    push @vertices, @d, @n3, @c, @n3, @g, @n3;
    push @vertices, @g, @n3, @h, @n3, @d, @n3;

    my @n4 = (0, -1, 0);
    push @vertices, @f, @n4, @b, @n4, @a, @n4;
    push @vertices, @a, @n4, @e, @n4, @f, @n4;

    my @n5 = (0, 0, 1);
    push @vertices, @a, @n5, @d, @n5, @h, @n5;
    push @vertices, @h, @n5, @e, @n5, @a, @n5;

    my @n6 = (0, 0, -1);
    push @vertices, @g, @n6, @c, @n6, @b, @n6;
    push @vertices, @b, @n6, @f, @n6, @g, @n6;

    @vertices;
}

sub make_shape {
    my @shapes = @{(shift)};
    my @vertices;
    for my $shape (@shapes) {
	my $type = $shape->{type};
	if ($type eq 'box') {
	    push @vertices, create_box(@{$shape->{pos}}, @{$shape->{size}});
	} else {
	    croak "unknown shape: $shape";
	}
    }
    @vertices;
}


1;
