package EnsEMBL::Web::ZMenu::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift; 
  my $hub  = $self->hub;
  my $v_id = $hub->param('vid');
  
  return unless $v_id;
  
  my $vf              = $hub->param('vf');
  my $db_adaptor      = $hub->database('variation');
  my $var_adaptor     = $db_adaptor->get_StructuralVariation;
  my $variation       = $var_adaptor->fetch_by_dbID($v_id); 
  my $seq_region      = $variation->slice->seq_region_name; 
  my $seq_region_type = $variation->slice->coord_system->name;
  my $neat_sr_name    = $self->neat_sr_name($seq_region_type, $seq_region);
  my $start           = ($variation->slice->start  + $variation->start) - 1;
  my $formatted_start = $self->thousandify($start);
  my $end             = ($variation->slice->start + $variation->end) - 1;
  my $formatted_end   = $self->thousandify($end);
  my $position        = $neat_sr_name . ':' . $formatted_start . '-' . $formatted_end;
  my $length          = $end - $start;
  my $max_length      = ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1) * 1e6; 
	my $pubmed_link     = '';
	my $location_link;
	my $study_name		  = $variation->study_name;
	my $description     = $variation->study_description;
	my $class						= $variation->class;
	
	if (! $description) {
		$description = $variation->source_description;
	}
	
  if ($length > $max_length) {  
    $location_link = $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => $seq_region . ':' . $start . '-' . $end,
      cytoview => 'variation_feature_structural=normal',
    });
  } else {
    $location_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $seq_region . ':' . $start . '-' . $end,
    });
  }
  
  if ($description =~/PMID/) {
    my @description_string = split (':', $description);
    my $pubmed_id = pop @description_string;
    $pubmed_id =~ s/\s+.+//g;
    $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);  
  }    

	my $sv_caption = 'Structural variation: ';
	if ($class eq 'CNV_PROBE') {
		$sv_caption = 'CNV probe: ';
	}
  $self->caption($sv_caption . $variation->variation_name);

  $self->add_entry({
    label_html => $variation->variation_name.' properties',
    link       => $hub->url({
      type     => 'StructuralVariation',
      action   => 'Summary',
      sv       => $variation->variation_name,
    })
  });

  $self->add_entry({
    type  => 'Source',
    label => $variation->source,
  });
	
	
	if ($study_name ne '') {
		my $study_url = $variation->study_url;
		$self->add_entry({
    	type  => 'Study',
    	label => $study_name,
    	link  => $study_url, 
  	});
	}

  $self->add_entry({
    type  => 'Description',
    label => $description,
    link  => $pubmed_link, 
  });

  $self->add_entry({
    type  => 'Class',
    label => $class,
  });

  $self->add_entry({
    type  => 'Location',
    label => $position,
    link  => $location_link,
  });
}
1;
