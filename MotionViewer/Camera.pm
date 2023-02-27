package MotionViewer::Camera;

#use OpenGL::GLUT qw(:constants);
use GLM;
use OpenGL::GLFW qw(:all);
use Math::Trig;

sub new {
    my $class = shift;
    my $this = bless {@_}, $class;
    $this->yaw(0) unless defined $this->{yaw};
    $this->pitch(0) unless defined $this->{pitch};
    $this->center(GLM::Vec3->new(0)) unless defined $this->{center};
    $this->distance(2) unless defined $this->{distance};
    $this->fovy(45) unless defined $this->{fovy};
    $this->aspect(1) unless defined $this->{aspect};
    $this->near(0.1) unless defined $this->{near};
    $this->far(1000) unless defined $this->{far};
    $this->up(GLM::Vec3->new(0, 0, 1));
    $this->update_view_matrix;
    $this;
}

sub yaw {
    my $this = shift;
    $this->{yaw} = shift if @_;
    $this->{yaw};
}

sub pitch {
    my $this = shift;
    $this->{pitch} = shift if @_;
    if ($this->{pitch} > 90) {
        $this->{pitch} = 90;
    } elsif ($this->{pitch} < -90) {
        $this->{pitch} = -90;
    }
    $this->{pitch};
}

sub center {
    my $this = shift;
    $this->{center} = shift if @_;
    $this->{center};
}

sub up {
    my $this = shift;
    $this->{up} = shift if @_;
    $this->{up};
}

sub distance {
    my $this = shift;
    $this->{distance} = shift if @_;
    if ($this->{distance} < 0.1) {
        $this->{distance} = 0.1;
    }
    $this->{distance};
}

sub fovy {
    my $this = shift;
    $this->{fovy} = shift if @_;
    $this->{fovy};
}

sub aspect {
    my $this = shift;
    $this->{aspect} = shift if @_;
    $this->{aspect};
}

sub near {
    my $this = shift;
    $this->{near} = shift if @_;
    $this->{near};
}

sub far {
    my $this = shift;
    $this->{far} = shift if @_;
    $this->{far};
}

sub update_view_matrix {
    my $this = shift;
    my $pitch = deg2rad $this->pitch;
    my $yaw = deg2rad $this->yaw;
    my $z = sin $pitch;
    my $r = cos $pitch;
    my $x = $r * sin($yaw);
    my $y = $r * cos($yaw);
    my $d = GLM::Vec3->new($x, $y, $z) * $this->distance;
    my $eye = $this->center + $d;
    #print 'eye :' . $eye->to_string . "\n";
    #print 'center :' . $this->center->to_string . "\n";
    $this->{view_matrix} = GLM::Functions::lookAt($eye, $this->center, $this->up);
}

sub view_matrix {
    my $this = shift;
    $this->{view_matrix};
}

sub proj_matrix {
    my $this = shift;
    GLM::Functions::perspective($this->fovy, $this->aspect, $this->near, $this->far);
}

sub keyboard_handler {
    my ($this, undef, $key, undef, $action) = @_;
    if ($action == GLFW_PRESS) {
	if ($key == GLFW_KEY_X) {
	    $this->{x_down} = 1;
	} elsif ($key == GLFW_KEY_Y) {
	    $this->{y_down} = 1;
	} elsif ($key == GLFW_KEY_Z) {
	    $this->{z_down} = 1;
	}
    } elsif ($action == GLFW_RELEASE) {
	if ($key == GLFW_KEY_X) {
	    $this->{x_down} = 0;
	} elsif ($key == GLFW_KEY_Y) {
	    $this->{y_down} = 0;
	} elsif ($key == GLFW_KEY_Z) {
	    $this->{z_down} = 0;
	}
    }
}

sub mouse_button_handler {
    my ($this, undef, $button, $action) = @_;
    if ($action == GLFW_PRESS) {
        if ($button == GLFW_MOUSE_BUTTON_LEFT) {
            $this->{left_button} = 1;
        } elsif ($button == GLFW_MOUSE_BUTTON_RIGHT) {
            $this->{right_button} = 1;
        }
    } elsif ($action == GLFW_RELEASE) {
        if ($button == GLFW_MOUSE_BUTTON_LEFT) {
            $this->{left_button} = 0;
        } elsif ($button == GLFW_MOUSE_BUTTON_RIGHT) {
            $this->{right_button} = 0;
        }
    }
}

my $rot_speed = 0.1;
my $zoom_speed_cursor = 0.005;
my $zoom_speed_scroll = 0.1;
my $pan_speed = 0.005;

sub cursor_pos_handler {
    my ($this, undef, $x, $y) = @_;
    my $x_offset = $x - $this->{last_x};
    my $y_offset = $y - $this->{last_y};
    #print 'yaw: ' . $this->yaw . "\n";
    #print 'pitch: ' . $this->pitch . "\n";
    if ($this->{left_button}) {
        if ($this->{x_down}) {
            $this->center($this->center + GLM::Vec3->new($y_offset * $pan_speed, 0, 0));
        } elsif ($this->{y_down}) {
            $this->center($this->center + GLM::Vec3->new(0, $y_offset * $pan_speed, 0));
        } elsif ($this->{z_down}) {
            $this->center($this->center + GLM::Vec3->new(0, 0, $y_offset * $pan_speed));
        } else {
            $this->yaw($this->yaw + $x_offset * $rot_speed);
            $this->pitch($this->pitch + $y_offset * $rot_speed);
        }
    } elsif ($this->{right_button}) {
        $this->distance($this->distance + $y_offset * $zoom_speed_cursor);
    }
    $this->update_view_matrix;
    $this->{last_x} = $x;
    $this->{last_y} = $y;
}

sub scroll_handler {
    my ($this, undef, $dx, $dy) = @_;
    $this->distance($this->distance - $dy * $zoom_speed_scroll);
    $this->update_view_matrix;
}

1;
