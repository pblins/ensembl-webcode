package Bio::EnsEMBL::GlyphSet::P_domain;
use strict;
no warnings "uninitialized";
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;

## Variables defined in UserConfig.pm 
## 'caption'   -> Track label
## 'logicname' -> Logic name

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $label = new Sanger::Graphics::Glyph::Text({
    'text'      => $self->my_config('caption'),
    'font'      => 'Small',
    'absolutey' => 1,
  });
  $self->label($label);
}

sub _init {
  my ($self) = @_;
  my %hash;
  my $y             = 0;
  my $h             = 4;
  my @bitmap        = undef;
  my $protein       = $self->{'container'};
  return unless $protein->dbID;
  return unless $self->check();
  my $Config        = $self->{'config'};
  my $pix_per_bp    = $Config->transform->{'scalex'};
  my $bitmap_length = int($protein->length() * $pix_per_bp);

  my $logic_name    = $self->my_config( 'logic_name' );
  my $URL_key       = $self->my_config( 'url_key'    ) || uc($logic_name);
  my $label         = $self->my_config( 'caption'    ) || uc($logic_name);
  my $depth         = $self->my_config( 'dep'        );
  my $colour        = $self->my_config( 'col'        );
  my $font          = "Small";
  my ($fontwidth, $fontheight)  = $Config->texthelper->real_px2bp($font);

warn ">>> $logic_name <<<";
  my @ps_feat = @{$protein->get_all_ProteinFeatures( $logic_name )};

  foreach my $feat(@ps_feat) {
     push(@{$hash{$feat->hseqname}},$feat);
  }
    
  foreach my $key (keys %hash) {
    my @row = @{$hash{$key}};
    my $desc = $row[0]->idesc();
    my $href = $self->ID_URL( $URL_key, $key );

    my @rect = ();
    my $prsave;
    my ($minx, $maxx);

    my @row = @{$hash{$key}};
    foreach my $pr (@row) {
      my $x  = $pr->start();
      $minx  = $x if ($x < $minx || !defined($minx));
      my $w  = $pr->end() - $x;
      $maxx  = $pr->end() if ($pr->end() > $maxx || !defined($maxx));
      my $id = $pr->hseqname();
      push @rect, new Sanger::Graphics::Glyph::Rect({
        'x'        => $x,
        'y'        => $y,
        'width'    => $w,
        'height'   => $h,
        'colour'   => $colour,
      });
      $prsave = $pr;
    }

    my $Composite = new Sanger::Graphics::Glyph::Composite({
      'x'     => $minx,
      'y'     => 0,
      'href'  => $href,
      'zmenu' => {
      'caption' => $label." Domain",
        $key     => $href,
        ($prsave->idesc() ? ($prsave->idesc,'') : ()),
        "aa: $minx - $maxx"
      },
    });
    $Composite->push(@rect);

    ##### add a domain linker
    $Composite->push(new Sanger::Graphics::Glyph::Rect({
      'x'        => $minx,
      'y'        => $y + 2,
      'width'    => $maxx - $minx,
      'height'   => 0,
      'colour'   => $colour,
      'absolutey' => 1,
    }));

    #### add a label
    my $desc = $prsave->idesc() || $key;
    $self->push(new Sanger::Graphics::Glyph::Text({
      'font'   => $font,
      'text'   => $desc,
      'x'      => $row[0]->start(),
      'y'      => $h + 1,
      'height' => $fontheight,
      'width'  => $fontwidth * length($desc),
      'colour' => $colour,
      'absolutey' => 1
    }));

    if($depth>0) {
      my $bump_start = int($Composite->x() * $pix_per_bp);
      my $bump_end = $bump_start + int( $Composite->width / $pix_per_bp);
      $bump_start = 0            if $bump_start < 0;
      $bump_end = $bitmap_length if $bump_end > $bitmap_length;
      if( $bump_end > $bump_start ) {
        my $row = & Sanger::Graphics::Bump::bump_row( $bump_start, $bump_end, $bitmap_length, \@bitmap );
        $Composite->y($Composite->y() + ( $row * ( 2 + $h + $fontheight))) if $row;
      }
    }
    $self->push($Composite);
  }
}

1;
