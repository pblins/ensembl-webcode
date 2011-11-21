package EnsEMBL::Web::Object::Experiment;

### NAME: EnsEMBL::Web::Object::Experiment
### Web::Object drived object for Experiment tab

use strict;

use URI::Escape qw(uri_escape uri_unescape);

use base qw(EnsEMBL::Web::Object);

sub new {
  ## @overrides
  ## @constructor
  ## Populates the data from the db and caches it before returning the object
  my $self                  = shift->SUPER::new(@_);
  my $param                 = $self->hub->param('ex');

  my $funcgen_db_adaptor    = $self->hub->database('funcgen');
  my $feature_set_adaptor   = $funcgen_db_adaptor->get_FeatureSetAdaptor;

  my $param_to_filter_map   = $self->{'_param_to_filter_map'}   = {'all' => 'All', 'cell_type' => 'Cell/Tissue', 'evidence_type' => 'Evidence type', 'project' => 'Project'};
  my $grouped_feature_sets  = $self->{'_grouped_feature_sets'}  = $funcgen_db_adaptor->get_ExperimentAdaptor->fetch_experiment_filter_counts;
  my $feature_sets_info     = $self->{'_feature_sets_info'}     = [];
  my $feature_sets          = [];

  $self->{'_filter_to_param_map'} = { reverse %{$self->{'_param_to_filter_map'}} };

  # Get the feature set according to the url param
  if ($param =~ /^name\-(.+)$/) {
    $feature_sets = [ $feature_set_adaptor->fetch_by_name($1) || () ];
  }
  else {
    my $constraints = {};
    if ($param ne 'all') {
      my $delimiter = chop $param;
      my $filters   = { split /$delimiter/, $param };
      exists $param_to_filter_map->{$_} and $filters->{$_} = uri_unescape($filters->{$_}) or delete $filters->{$_} for keys %$filters;

      $self->{'_param_filters'} = $filters;

      while (my ($filter, $value) = each(%$filters)) {
        if ($filter eq 'cell_type') {
          $constraints->{'cell_type'} = $funcgen_db_adaptor->get_CellTypeAdaptor->fetch_by_name($value);
        }
        elsif ($filter eq 'evidence_type') {
          $constraints->{'evidence_type'} = $value;
        }
        elsif ($filter eq 'project') {
          $constraints->{'project'} = $funcgen_db_adaptor->get_ExperimentalGroupAdaptor->fetch_by_name($value);
        }
      }
    }
    $feature_sets = $feature_set_adaptor->fetch_all_displayable_by_type('annotated', keys %$constraints ? {'constraints' => $constraints} : ());
  }

  my $binding_matrix_adaptor      = $funcgen_db_adaptor->get_BindingMatrixAdaptor;
  my $regulatory_evidence_labels  = $funcgen_db_adaptor->get_FeatureTypeAdaptor->get_regulatory_evidence_labels;

  # Get info for all feature sets and pack it in an array of hashes
  foreach my $feature_set (@$feature_sets) {

    my $experiment = $feature_set->get_Experiment;
    if (!$experiment) {
      warn "Failed to get Experiment for FeatureSet:\t".$feature_set->name;
      next;
    }

    my $experiment_group  = $experiment->experimental_group;
    $experiment_group     = undef unless $experiment_group->is_project;
    my $project_name      = $experiment_group ? $experiment_group->name : '';
    my $source_info       = $experiment->source_info; # returns [ source_label, source_link ]
    my $cell_type         = $feature_set->cell_type;
    my $cell_type_name    = $cell_type->name;
    my $feature_type      = $feature_set->feature_type;
    my $evidence_label    = $feature_type->evidence_type_label;

    push @$feature_sets_info, {
      'source_label'        => $source_info->[0],
      'source_link'         => $source_info->[1],
      'project_name'        => $project_name,
      'project_url'         => $experiment_group ? $experiment_group->url : '',
      'feature_set_name'    => $feature_set->name,
      'feature_type_name'   => $feature_type->name,
      'evidence_label'      => $evidence_label,
      'cell_type_name'      => $cell_type_name,
      'efo_id'              => $cell_type->efo_id,
      'xref_genes'          => [ map $_->primary_id, @{$feature_type->get_all_Gene_DBEntries} ],
      'binding_motifs'      => [ map {$_->name} map { @{$binding_matrix_adaptor->fetch_all_by_FeatureType($_)} } ($feature_type, @{$feature_type->associated_feature_types}) ]
    };

    $cell_type_name and $grouped_feature_sets->{'Cell/Tissue'}{$cell_type_name}{'filtered'}++;
    $evidence_label and $grouped_feature_sets->{'Evidence type'}{$evidence_label}{'filtered'}++;
    $project_name   and $grouped_feature_sets->{'Project'}{$project_name}{'filtered'}++;
  }

  return $self;
}

sub short_caption   { 'Experiment'  }
sub caption         { 'Experiment'  }
sub default_action  { 'Sources'     }

sub get_grouped_feature_sets {
  ## Gets a data structure of feature sets grouped according to Project, Cell/Tissue and Evidence Type
  ## @return HashRef with keys Project, Cell/Tissue, Evidence Type and All
  return shift->{'_grouped_feature_sets'};
}

sub get_feature_sets_info {
  ## Gets the array of all information about all feature sets according to the url param 'ex'
  ## @return ArrayRef
  return shift->{'_feature_sets_info'};
}

sub is_single_feature_view {
  ## Tells whether a single feature should be displayed - acc to the ex param
  my $self = shift;
  return $self->hub->param('ex') =~ /^name\-/ ? 1 : undef;
}

sub total_experiments {
  ## Gets the number of all experiments without any filter applied
  ## @return int
  return shift->{'_grouped_feature_sets'}{'All'}{'All'}{'count'} || 0;
}

sub applied_filters {
  ## Returns the filters applied to filter the feature sets info
  ## @return HashRef with keys as filter names
  return { map {$_} %{shift->{'_param_filters'} || {}} };
}

sub is_filter_applied {
  ## Checks whether a filter is already applied or not
  ## @return 1 or undef accordingly
  my ($self, $filter_name, $value) = @_;

  return 1 if $self->{'_filter_to_param_map'}{$filter_name} && exists $self->applied_filters->{$self->{'_filter_to_param_map'}{$filter_name}} && $self->applied_filters->{$self->{'_filter_to_param_map'}{$filter_name}} eq $value;
  return undef;
}

sub get_url_param {
  ## Takes filter name(s) and value(s) and returns corresponding param name for the url
  ## @param Hashref with keys as filter names and values as filter values
  ## @param Flag to tell whether to add, remove the given filters from existing filters, or ignore the existing filters
  ##  - 0  Ignore the existing filters
  ##  - 1  Add the given filters to existing ones
  ##  - -1 Remove the given filters from the existing ones
  ## @return String to go inside the URL param 'ex' as value
  my ($self, $filters, $flag) = @_;

  return 'all' if !scalar keys %$filters || exists $filters->{'All'};

  $self->{'_filter_to_param_map'} ||= { reverse %{$self->{'_param_to_filter_map'}} };

  my $params = $flag ? $self->applied_filters : {};
  while (my ($filter, $value) = each %$filters) {
    if (my $param_for_filter = $self->{'_filter_to_param_map'}{$filter}) {
      if ($flag >= 0) {
        $params->{$param_for_filter} = $value;
      }
      else {
        if ($params->{$param_for_filter} eq $value) {
          delete $params->{$param_for_filter};
        }
      }
    }
  }

  my $param_str   = join '', %$params;
  my $delimiters  = [ qw(_ ,), ('a'..'z'), ('A'..'Z'), (1..9) ];
  my $counter     = 0;
  my $delimiter   = '-';
  $delimiter      = $delimiters->[$counter++] while $delimiter && index($param_str, $delimiter) >= 0;

  return join($delimiter, (map {$_, uri_escape($params->{$_})} sort keys %$params), '') || 'all';
}

1;