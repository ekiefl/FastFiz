package Pool;
use Pool::Fiz;
use Pool::Rules;
use strict;
use Exporter;

our @EXPORT = qw(pocketToBoundary);
our @ISA = qw(Exporter);

our $TESTPOS = [
          {
            'id' => 0,
            'pos' => {
                       'y' => '1.69936',
                       'x' => '0.558'
                     },
            'state' => 1
          },
          {
            'id' => 1,
            'pos' => {
                       'y' => '0.559000597930097',
                       'x' => '0.557999367566048'
                     },
            'state' => 1
          },
          {
            'id' => 2,
            'pos' => {
                       'y' => '0.460008500953604',
                       'x' => '0.500847195081341'
                     },
            'state' => 1
          },
          {
            'id' => 3,
            'pos' => {
                       'y' => '0.410512009882739',
                       'x' => '0.529423556096199'
                     },
            'state' => 1
          },
          {
            'id' => 4,
            'pos' => {
                       'y' => '0.410512183345183',
                       'x' => '0.643729652509769'
                     },
            'state' => 1
          },
          {
            'id' => 5,
            'pos' => {
                       'y' => '0.361016741557515',
                       'x' => '0.443694023066194'
                     },
            'state' => 1
          },
          {
            'id' => 6,
            'pos' => {
                       'y' => '0.361016810947913',
                       'x' => '0.558000099631911'
                     },
            'state' => 1
          },
          {
            'id' => 7,
            'pos' => {
                       'y' => '0.460008280590248',
                       'x' => '0.615153150062925'
                     },
            'state' => 1
          },
          {
            'id' => 8,
            'pos' => {
                       'y' => '0.460008223471549',
                       'x' => '0.557999700457478'
                     },
            'state' => 1
          },
          {
            'id' => 9,
            'pos' => {
                       'y' => '0.50950430210508',
                       'x' => '0.529422996558498'
                     },
            'state' => 1
          },
          {
            'id' => 10,
            'pos' => {
                       'y' => '0.509504203831179',
                       'x' => '0.586576189838268'
                     },
            'state' => 1
          },
          {
            'id' => 11,
            'pos' => {
                       'y' => '0.4105116482949',
                       'x' => '0.586576010177833'
                     },
            'state' => 1
          },
          {
            'id' => 12,
            'pos' => {
                       'y' => '0.410512295773228',
                       'x' => '0.472270951211107'
                     },
            'state' => 1
          },
          {
            'id' => 13,
            'pos' => {
                       'y' => '0.361016129753731',
                       'x' => '0.672306157484187'
                     },
            'state' => 1
          },
          {
            'id' => 14,
            'pos' => {
                       'y' => '0.36101666343594',
                       'x' => '0.500847619377353'
                     },
            'state' => 1
          },
          {
            'id' => 15,
            'pos' => {
                       'y' => '0.361016428261082',
                       'x' => '0.615152802450617'
                     },
            'state' => 1
          }
        ];

sub pocketToBoundary {
  my $pocket=shift;
  return undef unless defined($pocket);
  if ($pocket == $Pool::Fiz::SW) {
    return $Pool::Fiz::SW_POCKET;
  } elsif ($pocket == $Pool::Fiz::W) {
    return $Pool::Fiz::W_POCKET;
  } elsif ($pocket == $Pool::Fiz::NW) {
    return $Pool::Fiz::NW_POCKET;
  } elsif ($pocket == $Pool::Fiz::NE) {
    return $Pool::Fiz::NE_POCKET;
  } elsif ($pocket == $Pool::Fiz::E) {
    return $Pool::Fiz::E_POCKET;
  } elsif ($pocket == $Pool::Fiz::SE) {
    return $Pool::Fiz::SE_POCKET;
  }
  return $Pool::Fiz::UNKNOWN_BOUNDARY;
}

package Pool::Fiz::Vector;

sub toPerl {
  my $self=shift;
  my %vec;
  $vec{'x'}=$self->swig_x_get();
  $vec{'y'}=$self->swig_y_get();
  $vec{'z'}=$self->swig_z_get();
  return \%vec;
}

package Pool::Fiz::Ball;

sub toPerl {
  my $self=shift;
  my $full=shift;
  my %ball;
  $ball{state}=$self->getState();
  my $pos=$self->getPos();
  $ball{pos}{'x'}=$pos->swig_x_get();
  $ball{pos}{'y'}=$pos->swig_y_get();
  if ($full) {
    $ball{velocity}=$self->getVelocity()->toPerl();
    $ball{spin}=$self->getSpin()->toPerl();
  }
  $ball{id}=$self->getID();
  return \%ball;
}

package Pool::Fiz::TableState;

# Count balls in current state
sub countBalls {
  my $self=shift;
  my @count;
  for my $i ($Pool::Fiz::ONE..$Pool::Fiz::EIGHT) {
    $count[0]++ if $self->getBall($i)->getState()==$Pool::Fiz::STATIONARY;
  }
  for my $i ($Pool::Fiz::EIGHT..$Pool::Fiz::FIFTEEN) {
    $count[1]++ if $self->getBall($i)->getState()==$Pool::Fiz::STATIONARY;
  }
  return @count;
}


# Convert a TableState to a perl array with all data
sub toPerl {
  my $self=shift;
  my $full=shift;
  my @result;
  for my $i (0..15) {
    my $ball=$self->getBall($i)->toPerl($full);
    push @result,$ball;
  }
  for my $b (@_) {
    my $ball=$b->toPerl($full);
    $result[$ball->{id}]=$ball;
  }
  return \@result;
}

sub fromPerl {
  my $self=shift;
  my $state=shift;
  for my $ball (@$state) {
    $self->setBall($ball->{id},$ball->{state},$ball->{pos}{x},$ball->{pos}{'y'});
  }
  return $self;
}

# Retrieve a ball and place it on the foot spot.
#sub spotBall {
#  my $self=shift;
#  my $table=shift;
#  my $ball=shift;
#  # TODO: Check and correct collisions
#  $self->setBall($ball,$poolfiz::STATIONARY,$table->getFootSpot());
#}

package Pool::Fiz::Shot;

# Black magic to make getEventList return a perl list instead of an ugly
# C++ wrapper

*_getEventList=*getEventList;

sub __getEventList {
  my $self=shift;
  my $evlist=$self->_getEventList(@_);
  if (wantarray) {
    my @evlist;
    for (my $i=0; $i<$evlist->size(); $i++) {
      push @evlist,$evlist->get($i);
    }
    return @evlist;
  } else {
    return $evlist;
  }
}

*getEventList=*__getEventList;


1;
