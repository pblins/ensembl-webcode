=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::simple_features;

### Standard rendering of data from simple_feature table (or similar)

use strict;

use EnsEMBL::Draw::Style::Blocks;

use base qw(EnsEMBL::Draw::GlyphSet);

sub features { 
  my $self     = shift;
  my $call     = 'get_all_' . ($self->my_config('type') || 'SimpleFeatures'); 
  my $db_type       = $self->my_config('db');
  my @features = map @{$self->{'container'}->$call($_, undef, $db_type)||[]}, @{$self->my_config('logic_names')||[]};
  
  return \@features;
}

sub render_labels {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->render_normal;
}

sub render_normal {
  my $self = shift;

  my $colours = $self->{'my_config'}->get('colours');
  my $default_colour = 'red';
  $self->{'my_config'}->set('bumped', 1);
  my $data = [];

  foreach my $f (@{$self->features || []}) {
    push @$data, {
                  'start'         => $f->start,
                  'end'           => $f->end,
                  'colour'        => $colours->{$f->analysis->logic_name}{'default'}
                                        || $default_colour,
                  'label'         => $f->display_id,
                  'label_colour'  => $colours->{$f->analysis->logic_name}{'text'}
                                        || $colours->{$f->analysis->logic_name}{'default'}
                                        || $default_colour,
                  'href'          => $self->href($f),
                  'title'         => $self->title($f),
                  };
  }

  if (scalar(@$data)) {
    my $config = $self->track_style_config;
    my $style  = EnsEMBL::Draw::Style::Blocks->new($config, $data);
    $self->push($style->create_glyphs);
  }
  else {
    ## No features show "empty track line" if option set
    my $track_name = $self->label_text || '';
    $self->errorTrack("No $track_name features in this region") if $self->{'config'}->get_option('opt_empty_tracks') == 1;
  }
}

sub title {
  my ($self, $f)    = @_;
  my ($start, $end) = $self->slice2sr($f->start, $f->end);
  my $score = length($f->score) ? sprintf('score: %s;', $f->score) : '';
  return sprintf '%s: %s; %s bp: %s', $f->analysis->logic_name, $f->display_label, $score, "$start-$end";
}

sub href {
  my ($self, $f) = @_;
  my $ext_url = $self->my_config('ext_url');
  
  return undef unless $ext_url;
  
  my ($start, $end) = $self->slice2sr($f->start, $f->end);
  
  return $self->_url({
    action        => 'SimpleFeature',
    logic_name    => $f->analysis->logic_name,
    display_label => $f->display_label,
    score         => $f->score,
    bp            => "$start-$end",
    ext_url       => $ext_url
  }); 
}

1;
