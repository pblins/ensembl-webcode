# $Id$

package EnsEMBL::Web::ViewConfig::Variation::FlankingSequence;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->set_defaults({
    flank_size      => 400,
    snp_display     => 'yes',
    select_sequence => 'both',
    hide_long_snps  => 'yes',
  });

  $self->title = 'Flanking sequence';
}

sub form {
  my $self    = shift;
  my %options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Length of reference flanking sequence to display',
    name   => 'flank_size',
    values => [
      { value => '100',  caption => '100bp'  },
      { value => '200',  caption => '200bp'  },
      { value => '300',  caption => '300bp'  },
      { value => '400',  caption => '400bp'  },
      { value => '500',  caption => '500bp'  },
      { value => '500',  caption => '500bp'  },
      { value => '1000', caption => '1000bp' },
    ]
  });  

  $self->add_form_element({
    type   => 'DropDown', 
    select => 'select',
    name   => 'select_sequence',
    label  => 'Sequence selection',
    values => [
      { value => 'both', caption => "Upstream and downstream sequences"   },
      { value => 'up',   caption => "Upstream sequence only (5')"   },
      { value => 'down', caption => "Downstream sequence only (3')" },
    ]
  });
  
  $self->add_form_element({ 
    type   => 'YesNo', 
    name   => 'snp_display', 
    select => 'select', 
    label  => 'Show variations in flanking sequence'
  });
  
  $self->add_form_element($options{'hide_long_snps'});
}

1;
