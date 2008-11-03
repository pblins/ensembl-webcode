package EnsEMBL::Web::Component::Location::Genome;

### Module to replace Karyoview

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);
use Data::Dumper;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::Text;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
  $self->configurable( 1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;

  my ($html, $table);
  
  my @features;
  if (my $id = $object->param('id')) { ## "FeatureView"
    my $f_objects = $object->create_features; ## Now that there's no Feature factory, we create these on the fly
    ## TODO: Should there be some generic object->hash functionality for use with drawing code?
    @features = @{$object->retrieve_features($f_objects)};
  }

  if ($object->species_defs->MAX_CHR_LENGTH) {

    ## Form with hidden elements for click-through
    my $config = $object->image_config_hash('Vkaryotype');
      $config->set_parameter(
        'container_width',
        $object->species_defs->MAX_CHR_LENGTH
      );

    my $ideo_height = $config->get_parameter('image_height');
    my $top_margin  = $config->get_parameter('top_margin');

    my $image    = $object->new_karyotype_image();

    my $pointers = [];
    my %pointer_defaults = (
      'DnaAlignFeature'     => ['red', 'rharrow'],
      'ProteinAlignFeature' => ['red', 'rharrow'],
      'RegulatoryFactor'    => ['red', 'rharrow'],
      'Gene'                => ['blue','lharrow'],
      'OligoProbe'          => ['red', 'rharrow'],
      'XRef'                => ['red', 'rharrow'],
      'UserData'            => ['purple', 'lharrow'],
    );
  
    my $hidden = {
      'karyotype'   => 'yes',
      'max_chr'     => $ideo_height,
      'margin'      => $top_margin,
      'chr'         => $object->seq_region_name,
      'start'       => $object->seq_region_start,
      'end'         => $object->seq_region_end,
    };

    ## Check if there is userdata
    ## TODO: this needs to come from control panel
    my $userdata = $object->get_session->get_tmp_data;
    my $user = $ENSEMBL_WEB_REGISTRY->get_user;
    my $has_userdata;
    my @uploads;
    if ($user) {
      @uploads = $user->uploads;
    }
    if( $userdata || @uploads ) {
      $has_userdata = 1;
      ## Set some basic image parameters
      $image->imagemap = 'no';
      $image->caption = 'Click on the image above to jump to an overview of the chromosome';
   
      ## Create pointers from user data
      if ($userdata->{'filename'}) {
        my $temp_pointers = $self->create_userdata_pointers($image, $userdata, $pointer_defaults{'UserData'});
        $object->param('aggregate_colour', $pointer_defaults{'UserData'}->[0]); ## Userdata setting overrides any other tracks
        push(@$pointers, $temp_pointers);
      }
      foreach my $upload (@uploads) {
        my @logic_names = split(', ', $upload->analyses);
        foreach my $logic_name (@logic_names) {
          my $upload_features = $object->retrieve_userdata;
          my $upload_pointers = $image->add_pointers( $object, {
            'config_name'  => 'Vkaryotype',
            'features'      => $upload_features,
            'color'         => $pointer_defaults{'UserData'}[0],
            'style'         => $pointer_defaults{'UserData'}[1]
          });
          $object->param('aggregate_colour', $pointer_defaults{'UserData'}[0]); 
          push(@$pointers, $upload_pointers);
        }
      }
    } 

    if (@features) { ## "FeatureView"
      my $text = @features > 1 ? 'Locations of features' : 'Location of feature';
      $html = qq(<strong>$text</strong>);
      $image->image_name = "feature-$species";
      $image->imagemap = 'yes';
      my $data_type = $object->param('type');
      $table = $self->feature_tables(\@features);;
      my $i = 0;
      my $zmenu_config;
      foreach my $ftype  (@features) {
	      my $pointer_ref = $image->add_pointers( $object, {
	        'config_name'  => 'Vkaryotype',
	        'features'      => \@features,
	        'zmenu_config'  => $zmenu_config,
	        'feature_type'  => $ftype,
	        'color'         => $object->param("col_$i")   || $pointer_defaults{$ftype->[2]}[0],
	        'style'         => $object->param("style_$i") || $pointer_defaults{$ftype->[2]}[1]}
			  );
	      push(@$pointers, $pointer_ref);
	      $i++;
      }
    } 
    if (!@$pointers) { ## Ordinary "KaryoView"
      $image->image_name = "karyotype-$species";
      $image->imagemap = 'no';
      $image->caption = 'Click on the image above to jump to an overview of the chromosome';
    }
  
    $image->set_button('form', 'id'=>'vclick', 'URL'=>"/$species/jump_to_location_view", 'hidden'=> $hidden);
    $image->karyotype( $object, $pointers, 'Vkaryotype' );
    $html .= $image->render;
    if ($has_userdata) {
      $html .= '<br /><p>Your uploaded data is displayed on the karyotype above, using '.$pointer_defaults{'UserData'}[0].' arrow pointers</p>';
    }
  }
  else {
    $html .= $self->_info( 'Unassembled genome', '<p>This genome has yet to be assembled into chromosomes</p>' );
  }

  $html .= $table;
  if (!$table) {
    my $file = '/ssi/species/stats_'.$object->species.'.html';
    $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file);
  }

  return $html;
}

sub feature_tables {
    my $self = shift;
    my $feature_dets = shift;
    my $object = $self->object;
    my $data_type = $object->param('ftype');
    my $html;
    my @tables;
    foreach my $feature_set (@{$feature_dets}) {
	my $features = $feature_set->[0];
	my $extra_columns = $feature_set->[1];
	my $feat_type = $feature_set->[2];
##
	#could show only gene links for xrefs, but probably not what is wanted:
#	next SET if ($feat_type eq 'Gene' && $data_type =~ /Xref/);
##
	my $data_type = ($feat_type eq 'Gene') ? 'Gene Information:'
	    : 'Feature Information:';

	my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
	if ($feat_type eq 'Gene') {
	    $table->add_columns({'key'=>'names',  'title'=>'Ensembl ID',      'width'=>'25%','align'=>'left' });
	    $table->add_columns({'key'=>'extname','title'=>'External names',  'width'=>'25%','align'=>'left' });

	}
	else {
	    $table->add_columns({'key'=>'loc',   'title'=>'Genomic location','width' =>'15%','align'=>'left' });
	    $table->add_columns({'key'=>'length','title'=>'Genomic length',  'width'=>'10%','align'=>'left' });
	    $table->add_columns({'key'=>'names', 'title'=>'Names(s)',        'width'=>'25%','align'=>'left' });
	}
	
	my $c = 1;
	for( @{$extra_columns||[]} ) {
	    $table->add_columns({'key'=>"extra_$c",'title'=>$_,'width'=>'10%','align'=>'left' });
	    $c++;
	}
	
	my @data = map { $_->[0] }
	    sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
		map { [$_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'}, $_->{'start'}] }
		    @{$features};
	foreach my $row ( @data ) {
	    my $contig_link = 'Unmapped';
	    my $names = '';
	    my $data_row;
	    if ($row->{'region'}) {
		$contig_link = sprintf('<a href="/%s/Location/View?r=%s:%d-%d;h=%s">%s:%d-%d(%d)</a>',
				       $object->species,
				       $row->{'region'}, $row->{'start'}, $row->{'end'}, $row->{'label'},
				       $row->{'region'}, $row->{'start'}, $row->{'end'},
				       $row->{'strand'});
		if ($feat_type eq 'Gene' && $row->{'label'}) {
		    $names = sprintf('<a href="/%s/Gene/Summary?g=%s;r=%s:%d-%d">%s</a>',
				     $object->species, $row->{'label'},
				     $row->{'region'}, $row->{'start'}, $row->{'end'},
				     $row->{'label'});
		    my $extname = $row->{'extname'};
		    my $desc =  $row->{'extra'}[0];
		    $data_row = { 'extname' => $extname, 'names' => $names};
		}
		else {
		    if ($feat_type !~ /align|RegulatoryFactor/i && $row->{'label'}) {
			$names = sprintf('<a href="/%s/Gene/Summary?g=%s;r=%s:%d-%d">%s</a>',
					 $object->species, $row->{'label'},
					 $row->{'region'}, $row->{'start'}, $row->{'end'},
					 $row->{'label'});
		    }
		    else {
			$names  = $row->{'label'} if $row->{'label'};
		    }
		    my $length = $row->{'length'};
		    $data_row = { 'loc'  => $contig_link, 'length' => $length, 'names' => $names, };
		}
	    }
	    my $c = 1;
	    for( @{$row->{'extra'}||[]} ) {
		$data_row->{"extra_$c"} = $_;
		$c++;
	    }
	    $c = 0;
	    for( @{$row->{'initial'}||[]} ) {
		$data_row->{"initial$c"} = $_;
		$c++;
	    }
	    $table->add_row($data_row);
	}
	if (@data) {
	    $html .= qq(<strong>$data_type</strong>);
	    $html .= $table->render;
	}
    }
    if (! $html) {
	my $id = $object->param('id');
	$html .= qq(<br /><br />No mapping of $id found<br /><br />);
    }
    return $html;
}

1;
