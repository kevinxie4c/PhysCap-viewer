#!/usr/bin/env perl
use Getopt::Long;
use OpenGL::Modern qw(:all);
use OpenGL::GLUT qw(:all);
use OpenGL::Array;
use GLM;
use Math::Trig;
use Image::PNG::Libpng ':all';
use Image::PNG::Const ':all';

use FindBin qw($Bin);
use lib $Bin;
use MotionViewer::Shader;
use MotionViewer::Buffer;
use MotionViewer::Camera;
use MotionViewer::Skeleton;
use strict;
use warnings;

my $win_id;
my ($screen_width, $screen_height) = (1280, 720);
my ($shader, $buffer, $camera);

my $orange = GLM::Vec3->new(1.0, 0.5, 0.2);
my $red    = GLM::Vec3->new(1.0, 0.0, 0.0);
my $blue   = GLM::Vec3->new(0.0, 0.0, 1.0);
my $white  = GLM::Vec3->new(1.0, 1.0, 1.0);
my $green  = GLM::Vec3->new(0.0, 1.0, 0.0);

my $identity_mat = GLM::Mat4->new(
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
);

my $animate = 0;
my $fps = 10; # 0.1 second per iteration. 10 Hz.
my $ffmpeg = $^O eq 'MSWin32' ? 'ffmpeg.exe': 'ffmpeg';
my $fh_ffmpeg;
my $recording = 0;
my $png_counter = 0;

my $floor_z = 0.2;
my ($floor_width, $floor_height) = (1000, 1000);
my $floor_buffer;
my $cube_buffer;
my ($sphere_buffer, $num_vertices_sphere);
my ($cylinder_buffer, $num_vertices_cylinder);
my ($cone_buffer, $num_vertices_cone);

my $shadow_map_shader;
my ($shadow_map_height, $shadow_map_width) = (8192, 8192);
my ($shadow_map_buffer, $shadow_map_texture);
my $light_space_matrix;
my ($light_near, $light_far) = (0.01, 10);
my $camera_cfg_file;

my $primitive_shader;

GetOptions();

my $skeleton;

# a     d
#  +---+
#  |\  |
#  | \ |
#  |  \|
#  +---+
# b     c
sub create_floor {
    my @n = (0, 1, 0);
    my @a = (-$floor_width / 2, -$floor_height / 2, $floor_z);
    my @b = (-$floor_width / 2,  $floor_height / 2, $floor_z);
    my @c = ( $floor_width / 2,  $floor_height / 2, $floor_z);
    my @d = ( $floor_width / 2, -$floor_height / 2, $floor_z);
    $floor_buffer = MotionViewer::Buffer->new(2, @a, @n, @b, @n, @c, @n, @a, @n, @c, @n, @d, @n);
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
sub create_cube {
    my (@a, @b, @c, @d, @e, @f, @g, @h);
    @a = (-0.5,  0.5, -0.5);
    @b = (-0.5, -0.5, -0.5);
    @c = (-0.5, -0.5,  0.5);
    @d = (-0.5,  0.5,  0.5);
    @e = ( 0.5,  0.5, -0.5);
    @f = ( 0.5, -0.5, -0.5);
    @g = ( 0.5, -0.5,  0.5);
    @h = ( 0.5,  0.5,  0.5);

    my @vertices;
    my @n1 = (-1, 0, 0);
    push @vertices, @a, @n1, @b, @n1, @c, @n1;
    push @vertices, @c, @n1, @d, @n1, @a, @n1;

    my @n2 = (1, 0, 0);
    push @vertices, @g, @n2, @f, @n2, @e, @n2;
    push @vertices, @e, @n2, @h, @n2, @g, @n2;

    my @n3 = (0, 0, 1);
    push @vertices, @d, @n3, @c, @n3, @g, @n3;
    push @vertices, @g, @n3, @h, @n3, @d, @n3;

    my @n4 = (0, 0, -1);
    push @vertices, @f, @n4, @b, @n4, @a, @n4;
    push @vertices, @a, @n4, @e, @n4, @f, @n4;

    my @n5 = (0, 1, 0);
    push @vertices, @a, @n5, @d, @n5, @h, @n5;
    push @vertices, @h, @n5, @e, @n5, @a, @n5;

    my @n6 = (0, -1, 0);
    push @vertices, @g, @n6, @c, @n6, @b, @n6;
    push @vertices, @b, @n6, @f, @n6, @g, @n6;

    $cube_buffer = MotionViewer::Buffer->new(2, @vertices);
}

sub create_sphere {
    my ($xo, $yo, $zo, $r, $s) = (0, 0, 0, 3, 20); # x, y, z, radius, slice
    my @vlist;
    for (my $i = 0; $i < $s; ++$i) {
        my $theta1 = pi / $s * $i;
        my $theta2 = pi / $s * ($i + 1);
        my $y1 = cos($theta1);
        my $y2 = cos($theta2);
        my $r1 = sin($theta1);
        my $r2 = sin($theta2);
        for (my $j = 0; $j < $s * 2; ++$j) {
            my $phi1 = pi / $s * $j;
            my $phi2 = pi / $s * ($j + 1);
            my $za = $r1 * cos($phi1);
            my $xa = $r1 * sin($phi1);
            my $zb = $r2 * cos($phi1);
            my $xb = $r2 * sin($phi1);
            my $zc = $r2 * cos($phi2);
            my $xc = $r2 * sin($phi2);
            my $zd = $r1 * cos($phi2);
            my $xd = $r1 * sin($phi2);
            my ($a, $b, $c, $d);
            my ($na, $nb, $nc, $nd);
            $na = GLM::Vec3->new($xa, $y1, $za);
            $nb = GLM::Vec3->new($xb, $y2, $zb);
            $nc = GLM::Vec3->new($xc, $y2, $zc);
            $nd = GLM::Vec3->new($xd, $y1, $zd);
            $a = $na * $r;
            $b = $nb * $r;
            $c = $nc * $r;
            $d = $nd * $r;
            my $o = GLM::Vec3->new($xo, $yo, $zo);
            $a += $o;
            $b += $o;
            $c += $o;
            $d += $o;
            $a = GLM::Vec4->new($a->x, $a->y, $a->z, 1);
            $b = GLM::Vec4->new($b->x, $b->y, $b->z, 1);
            $c = GLM::Vec4->new($c->x, $c->y, $c->z, 1);
            $d = GLM::Vec4->new($d->x, $d->y, $d->z, 1);
            $na = GLM::Vec4->new($na->x, $na->y, $na->z, 0);
            $nb = GLM::Vec4->new($nb->x, $nb->y, $nb->z, 0);
            $nc = GLM::Vec4->new($nc->x, $nc->y, $nc->z, 0);
            $nd = GLM::Vec4->new($nd->x, $nd->y, $nd->z, 0);
            push @vlist, $a, $na;
            push @vlist, $b, $nb;
            push @vlist, $c, $nc;
            push @vlist, $c, $nc;
            push @vlist, $d, $nd;
            push @vlist, $a, $na;
        }
    }
    my @vertices = map { ($_->x, $_->y, $_->z) } @vlist;
    $num_vertices_sphere = @vertices / (3 * 2);
    $sphere_buffer = MotionViewer::Buffer->new(2, @vertices);
}

sub create_cylinder {
    my ($r, $h, $s) = (1, 1, 20); # radius, half height, slice
    my @vlist;
    for (my $i = 0; $i < $s; ++$i) {
        my $theta1 = 2 * pi / $s * $i;
        my $theta2 = 2 * pi / $s * ($i + 1);
        my $x1 = sin($theta1);
        my $x2 = sin($theta2);
        my $y1 = cos($theta1);
        my $y2 = cos($theta2);
        my $n1 = GLM::Vec3->new($x1, $y1, 0);
        my $n2 = GLM::Vec3->new($x2, $y2, 0);
        my $a = GLM::Vec3->new($x1 * $r, $y1 * $r,  $h);
        my $b = GLM::Vec3->new($x1 * $r, $y1 * $r, -$h);
        my $c = GLM::Vec3->new($x2 * $r, $y2 * $r, -$h);
        my $d = GLM::Vec3->new($x2 * $r, $y2 * $r,  $h);
        push @vlist, $a, $n1;
        push @vlist, $b, $n1;
        push @vlist, $c, $n2;
        push @vlist, $c, $n2;
        push @vlist, $d, $n2;
        push @vlist, $a, $n1;
    }
    my @vertices = map { ($_->x, $_->y, $_->z) } @vlist;
    $num_vertices_cylinder = @vertices / (3 * 2);
    $cylinder_buffer = MotionViewer::Buffer->new(2, @vertices);
}

sub create_cone {
    my ($r, $h, $s) = (1, 1, 20); # radius, height, slice
    my @vlist;
    for (my $i = 0; $i < $s; ++$i) {
        my $theta1 = 2 * pi / $s * $i;
        my $theta2 = 2 * pi / $s * ($i + 1);
        my $x1 = sin($theta1);
        my $x2 = sin($theta2);
        my $y1 = cos($theta1);
        my $y2 = cos($theta2);
        my $v1 = GLM::Vec3->new($x1, $y1, 0)->normalized;
        my $v2 = GLM::Vec3->new($x2, $y2, 0)->normalized;
        my $u = GLM::Vec3->new(0, 0, 1);
        my $n1 = ($h * $v1 + $r * $u)->normalized;
        my $n2 = ($h * $v2 + $r * $u)->normalized;
        my $n3 = (($n1 + $n2) / 2)->normalized;
        my $a = GLM::Vec3->new($x1 * $r, $y1 * $r,  0);
        my $b = GLM::Vec3->new($x2 * $r, $y2 * $r,  0);
        my $c = GLM::Vec3->new(       0,        0, $h);
        push @vlist, $a, $n1;
        push @vlist, $b, $n2;
        push @vlist, $c, $n3;
    }
    my @vertices = map { ($_->x, $_->y, $_->z) } @vlist;
    $num_vertices_cone = @vertices / (3 * 2);
    $cone_buffer = MotionViewer::Buffer->new(2, @vertices);
}

sub draw_floor {
    $floor_buffer->bind;
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

sub draw_cube {
    die "usage: draw_cube(x, y, z)" if @_ < 3;
    my $translate = GLM::Functions::translate($identity_mat, GLM::Vec3->new(@_));
    $shader->set_mat4('model', $translate);
    $cube_buffer->bind;
    glDrawArrays(GL_TRIANGLES, 0, 36);
}

sub draw_sphere {
    die "usage: draw_sphere(x, y, z)" if @_ < 3;
    my $translate = GLM::Functions::translate($identity_mat, GLM::Vec3->new(@_));
    $shader->set_mat4('model', $translate);
    $sphere_buffer->bind;
    glDrawArrays(GL_TRIANGLES, 0, $num_vertices_sphere);
}

sub draw_cylinder {
    die "usage: draw_cylinder(x1, y1, z1, x2, y2, z2, r)" if @_ < 7;
    my ($x1, $y1, $z1, $x2, $y2, $z2, $r) = @_;
    my $a = GLM::Vec3->new($x1, $y1, $z1);
    my $b = GLM::Vec3->new($x2, $y2, $z2);
    my $v = $b - $a;
    my $scale = GLM::Functions::scale($identity_mat, GLM::Vec3->new($r, $r, $v->length / 2));
    my $rotate;
    if (abs($v->x) < 1e-6 && abs($v->y) < 1e-6) {
        $rotate = $identity_mat;
    } else {
        $v->normalize;
        my $u = GLM::Vec3->new(0, 0, 1);
        my $axis = $u->cross($v)->normalize;
        my $angle = acos($u->dot($v));
        $rotate = GLM::Functions::rotate($identity_mat, $angle, $axis);
    }
    my $translate = GLM::Functions::translate($identity_mat, ($a + $b) / 2);
    #print "$translate\n$rotate\n$scale\n";
    $shader->set_mat4('model', $translate * $rotate * $scale);
    $cylinder_buffer->bind;
    glDrawArrays(GL_TRIANGLES, 0, $num_vertices_cylinder);
}

sub draw_cone {
    die "usage: draw_cone(x1, y1, z1, x2, y2, z2, r)" if @_ < 7;
    my ($x1, $y1, $z1, $x2, $y2, $z2, $r) = @_;
    my $a = GLM::Vec3->new($x1, $y1, $z1);
    my $b = GLM::Vec3->new($x2, $y2, $z2);
    my $v = $b - $a;
    my $scale = GLM::Functions::scale($identity_mat, GLM::Vec3->new($r, $r, $v->length));
    my $rotate;
    if (abs($v->x) < 1e-6 && abs($v->y) < 1e-6) {
        $rotate = $identity_mat;
    } else {
        $v->normalize;
        my $u = GLM::Vec3->new(0, 0, 1);
        my $axis = $u->cross($v)->normalize;
        my $angle = acos($u->dot($v));
        $rotate = GLM::Functions::rotate($identity_mat, $angle, $axis);
    }
    my $translate = GLM::Functions::translate($identity_mat, $a);
    #print "$translate\n$rotate\n$scale\n";
    $shader->set_mat4('model', $translate * $rotate * $scale);
    $cone_buffer->bind;
    glDrawArrays(GL_TRIANGLES, 0, $num_vertices_cone);
}

sub draw_axis {
    die "usage: draw_cone(x1, y1, z1, x2, y2, z2)" if @_ < 6;
    my ($x1, $y1, $z1, $x2, $y2, $z2) = @_;
    my ($r1, $r2, $h) = (1, 2, 6);
    my $a = GLM::Vec3->new($x1, $y1, $z1);
    my $b = GLM::Vec3->new($x2, $y2, $z2);
    my $v = ($b - $a)->normalized;
    my $c = $b + 6 * $v;
    draw_cylinder($a->x, $a->y, $a->z, $b->x, $b->y, $b->z, $r1);
    draw_cone($b->x, $b->y, $b->z, $c->x, $c->y, $c->z, $r2);
}

sub draw_lines {
    my $line_buffer = MotionViewer::Buffer->new(1, @_);
    $line_buffer->bind;
    glDrawArrays(GL_LINES, 0, @_ / 3);
}

sub init_shadow_map {
    my $buffer_array = OpenGL::Array->new(1, GL_INT);
    glGenFramebuffers_c(1, $buffer_array->ptr);
    $shadow_map_buffer = ($buffer_array->retrieve(0, 1))[0];
    my $texture_array = OpenGL::Array->new(1, GL_INT);
    glGenTextures_c(1, $texture_array->ptr);
    $shadow_map_texture = ($texture_array->retrieve(0, 1))[0];
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, $shadow_map_texture);
    glTexImage2D_c(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, $shadow_map_width, $shadow_map_height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glBindFramebuffer(GL_FRAMEBUFFER, $shadow_map_buffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, $shadow_map_texture, 0);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

sub create_shadow_map {
    my $light_proj = GLM::Functions::ortho(-5, 5, -5, 5, $light_near, $light_far);
    my $light_view = GLM::Functions::lookAt($camera->center + GLM::Vec3->new(2), $camera->center, GLM::Vec3->new(0, 0, 1));
    $light_space_matrix = $light_proj * $light_view;
    $shadow_map_shader->use;
    $shadow_map_shader->set_mat4('lightSpaceMatrix', $light_space_matrix);
    glViewport(0, 0, $shadow_map_width, $shadow_map_height);
    glBindFramebuffer(GL_FRAMEBUFFER, $shadow_map_buffer);
    glClear(GL_DEPTH_BUFFER_BIT);

    $shadow_map_shader->set_mat4('model', $identity_mat);
    draw_floor;
    $skeleton->shader($shadow_map_shader);
    $skeleton->draw;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

sub destroy_shadow_map {
}

my ($prev_x, $prev_y, $prev_z);
my ($prev_x_weight, $prev_y_weight, $prev_z_weight) = (1, 1, 0);

sub render {
    glClearColor(0.529, 0.808, 0.922, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);

    create_shadow_map;

    glViewport(0, 0, $screen_width, $screen_height);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, $shadow_map_texture);

    $shader->use;
    $shader->set_mat4('lightSpaceMatrix', $light_space_matrix);
    $shader->set_mat4('view', $camera->view_matrix);
    $shader->set_mat4('proj', $camera->proj_matrix);
    $shader->set_float('alpha', 1.0);
    $shader->set_vec3('color', $white);
    $shader->set_mat4('model', $identity_mat);
    $shader->set_int('enableShadow', 1);
    $shader->set_int('checker', 1);
    draw_floor;
    $shader->set_int('checker', 0);

    $shader->set_vec3('color', $orange);
    $skeleton->shader($shader);
    $skeleton->draw;
    $shader->set_int('enableShadow', 0);

    glutSwapBuffers();
    if ($recording) {
        my $buffer = OpenGL::Array->new($screen_width * $screen_height * 4, GL_BYTE);
        glReadPixels_c(0, 0, $screen_width, $screen_height, GL_RGBA, GL_UNSIGNED_BYTE, $buffer->ptr);
        print $fh_ffmpeg $buffer->retrieve_data(0, $screen_width * $screen_height * 4);
    }
}

sub timer {
    if ($animate) {
        glutTimerFunc(1.0 / $fps * 1000, \&timer);
        glutPostRedisplay;
    }
}

sub keyboard {
    my ($key) = @_;
    if ($key == 27) { # ESC
        destroy_shadow_map;
        glutDestroyWindow($win_id);
    } elsif (lc(chr($key)) eq 'v') {
        $recording = !$recording;
        if ($recording) {
            open $fh_ffmpeg, '|-', "$ffmpeg -r $fps -f rawvideo -pix_fmt rgba -s ${screen_width}x${screen_height} -i - -threads 0 -preset fast -y -pix_fmt yuv420p -crf 1 -vf vflip output.mp4";
            binmode $fh_ffmpeg;
        } else {
            close $fh_ffmpeg;
        }
    } elsif (lc(chr($key)) eq 's') {
        my $png = create_write_struct;
        $png->set_IHDR({
                height     => $screen_height,
                width      => $screen_width,
                bit_depth  => 8,
                color_type => PNG_COLOR_TYPE_RGB_ALPHA,
            });
        my $buffer = OpenGL::Array->new($screen_width * $screen_height * 4, GL_BYTE);
        glReadBuffer(GL_FRONT);
        glReadPixels_c(0, 0, $screen_width, $screen_height, GL_RGBA, GL_UNSIGNED_BYTE, $buffer->ptr);
        my @rows;
        for (my $i = 0; $i < $screen_height; ++$i) {
            unshift @rows, $buffer->retrieve_data($i * $screen_width * 4, $screen_width * 4); # use unshift instead of push because we want to flip the png along y axis
        }
        $png->set_rows(\@rows);
        $png->write_png_file(sprintf('img%03d.png', $png_counter++));
    } elsif (lc(chr($key)) eq 'i') {
        print "yaw: ", $camera->yaw, "\n";
        print "pitch: ", $camera->pitch, "\n";
        print "distance: ", $camera->distance, "\n";
        print "center: ", $camera->center, "\n";
	#print "frame #: $frame\n";
    } elsif (lc(chr($key)) eq 'h') {
        print <<'HELP';

Keyboard
    ESC: exit.
    Space: animate.
    V: record video.
    S: screen shot.
    9: decrease alpha.
    0: increase alpha.

Mouse
    Left button: rotate. Translate with X, Y or Z pressed.
    Right button: zoom.

HELP
    }
    $camera->keyboard_handler(@_);
}

sub keyboard_up {
    $camera->keyboard_up_handler(@_);
}

sub mouse {
    $camera->mouse_handler(@_);
}

sub motion {
    $camera->motion_handler(@_);
    #$shader->use;
    #$shader->set_mat4('view', $camera->view_matrix);
    glutPostRedisplay;
}

glutInit;
glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE);
glutInitWindowSize($screen_width, $screen_height);
$win_id = glutCreateWindow("Viewer");
glutDisplayFunc(\&render);
glutKeyboardFunc(\&keyboard);
glutKeyboardUpFunc(\&keyboard_up);
glutMouseFunc(\&mouse);
glutMotionFunc(\&motion);
glutReshapeFunc(sub {
        ($screen_width, $screen_height) = @_;
        $camera->aspect($screen_width / $screen_height);
        #$shader->use;
        #$shader->set_mat4('proj', $camera->proj_matrix);
    });

die "glewInit failed" unless glewInit() == GLEW_OK;

glEnable(GL_DEPTH_TEST);
glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
$shader = MotionViewer::Shader->load(File::Spec->catdir($Bin, 'shaders/simple.vs'), File::Spec->catdir($Bin, 'shaders/simple.fs'));
$shadow_map_shader = MotionViewer::Shader->load(File::Spec->catdir($Bin, 'shaders/shadow_map.vs'), File::Spec->catdir($Bin, 'shaders/shadow_map.fs'));
$primitive_shader = MotionViewer::Shader->load(File::Spec->catdir($Bin, 'shaders/primitive.vs'), File::Spec->catdir($Bin, 'shaders/primitive.fs'));
$camera = MotionViewer::Camera->new(aspect => $screen_width / $screen_height);
if (defined($camera_cfg_file)) {
    open my $fh, '<', $camera_cfg_file or die "cannot open $camera_cfg_file";
    while (<$fh>) {
        chomp;
        if (/^\s*yaw:\s*(.*)$/) {
            $camera->yaw($1);
        } elsif (/^\s*pitch:\s*(.*)/) {
            $camera->pitch($1);
        } elsif (/^\s*distance:\s*(.*)/) {
            $camera->distance($1);
        } elsif (/^\s*near:\s*(.*)/) {
            $camera->near($1);
        } elsif (/^\s*far:\s*(.*)/) {
            $camera->far($1);
        } elsif (/^\s*center:\s*\[(.*)\]/) {
            $camera->center(GLM::Vec3->new(split(' ', $1)));
        }
    }
    close $fh;
}
$camera->update_view_matrix;

$shader->use;
$shader->set_vec3('lightIntensity', GLM::Vec3->new(1));
$shader->set_vec3('lightDir', GLM::Vec3->new(-1)->normalized);
$shader->set_int('checker', 0);

create_floor;
create_cube;
create_sphere;
create_cylinder;
create_cone;
init_shadow_map;

my @positions;
open my $fh, '<', 'positions.txt';
while (<$fh>) {
    chomp;
    push @positions, [split];
}
$skeleton = MotionViewer::Skeleton->load('character.json');
$skeleton->shader($shader);
$skeleton->set_positions(@{$positions[0]});

glutMainLoop();
