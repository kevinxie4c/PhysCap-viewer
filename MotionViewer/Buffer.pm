package MotionViewer::Buffer;

use Carp;
use OpenGL::Modern qw(:all);
use OpenGL::Array;

# TODO: add support for different attribute layouts
sub new {
    my $class = shift;
    croak 'usage: ' . $class . '->new($number_of_attributes, \@vertices, \@indices)' if @_ < 1;
    my $this = bless {}, $class;
    my ($num_attr, $vtx, $elm) = @_;
    my (@vertices, @elements);
    @vertices = @$vtx;
    @elements = @$elm if defined $elm;

    $this->vao_array(OpenGL::Array->new(1, GL_INT));
    glGenVertexArrays_c(1, $this->vao_array->ptr);
    glBindVertexArray($this->vao);

    $this->vbo_array(OpenGL::Array->new(1, GL_INT));
    glGenBuffers_c(1, $this->vbo_array->ptr);
    glBindBuffer(GL_ARRAY_BUFFER, $this->vbo);

    my $vertices_array = OpenGL::Array->new_list(GL_FLOAT, @vertices);
    glBufferData_c(GL_ARRAY_BUFFER, $vertices_array->offset(scalar(@vertices)) - $vertices_array->ptr, $vertices_array->ptr, GL_STATIC_DRAW);
    for (my $i = 0; $i < $num_attr; ++$i) {
        glVertexAttribPointer_c($i, 3, GL_FLOAT, GL_FALSE, $vertices_array->offset(3 * $num_attr) - $vertices_array->ptr, $vertices_array->offset(3 * $i) - $vertices_array->ptr);
        glEnableVertexAttribArray($i);
    }

    if (@elements) {
	$this->ebo_array(OpenGL::Array->new(1, GL_INT));
	glGenBuffers_c(1, $this->ebo_array->ptr);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, $this->ebo);
	my $indices_array = OpenGL::Array->new_list(GL_UNSIGNED_INT, @indices);
	glBufferData_c(GL_ELEMENT_ARRAY_BUFFER, $indices_array->offset(scalar(@indices)) - $indices_array->ptr, $indices_array->ptr, GL_STATIC_DRAW);
	# Should not add following?
	#glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    $this->{num_attr} = $num_attr;
    $this->{num_vert} = @vertices / (3 * $num_attr);
    $this->{num_elem} = @elements;

    $this;
}

sub vbo {
    my $this = shift;
    ($this->vbo_array->retrieve(0, 1))[0];
}

sub vao {
    my $this = shift;
    ($this->vao_array->retrieve(0, 1))[0];
}

sub ebo {
    my $this = shift;
    ($this->ebo_array->retrieve(0, 1))[0];
}

sub vbo_array {
    my $this = shift;
    $this->{vbo_array} = shift if @_;
    $this->{vbo_array};
}

sub vao_array {
    my $this = shift;
    $this->{vao_array} = shift if @_;
    $this->{vao_array};
}

sub vao_array {
    my $this = shift;
    $this->{ebo_array} = shift if @_;
    $this->{ebo_array};
}

sub num_attr {
    shift->{num_attr};
}

sub num_vert {
    shift->{num_vert};
}

sub num_elem {
    shift->{num_elem};
}

sub bind {
    my $this = shift;
    glBindVertexArray($this->vao);
}

sub unbind {
    my $this = shift;
    glBindVertexArray(0);
}

sub draw {
    my $this = shift;
    $this->bind;
    if (@elements) {
	glDrawElements_c(GL_TRIANGLES, $this->num_elem, GL_UNSIGNED_INT, 0);
    } else {
	glDrawArrays(GL_TRIANGLES, 0, $this->num_vert);
    }
    $this->unbind;
}

sub DESTROY {
    glDeleteVertexArrays_c(1, $this->vao_array->ptr);
    glDeleteBuffers_c(1, $this->vbo_array->ptr);
    glDeleteBuffers_c(1, $this->ebo_array->ptr);
}

1;
