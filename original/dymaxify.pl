#!/usr/bin/perl

use Imager;
use Geo::Dymaxion; 
use strict;
use warnings;

my $src = Imager->new;
$src->open( file => "blue_marble_2048.tif" );
my ($width, $height) = ($src->getwidth, $src->getheight);

my $dymax = Geo::Dymaxion->new( $width, $height );

my $dest = Imager->new( xsize => $width, ysize => $height );
$dest->box( xmin => 0,  ymin => 0, 
	    xmax => $width, ymax => $height,
	    color => [255, 255, 255, 0],
	    filled => 1 );

my $mask = Imager->new( xsize => $width, ysize => $height, channels => 1 );
$mask->box( xmin => 0,  ymin => 0, 
	    xmax => $width, ymax => $height,
	    color => [255], filled => 1 );

for (my $y = 0; $y < $height; $y++) {
    my $lat   = 90 - ($y / $height) * 180; 
    for (my $x = 0; $x < $width; $x++) {
	my $lon   = ($x / $width) * 360 - 180;
	my ($x1, $y1) = $dymax->plot( $lat, $lon );

	my $color = $src->getpixel( x => $x, y => $y );
	#$dest->box( xmin => $x1 - 1, ymin => $y1 - 1, 
	#	    xmax => $x1 + 1, ymax => $y1 + 1,
	#	    color => $color, filled => 1 );
	$dest->circle( x =>  $x1, y => $y1, r => 1.25, 
		       aa => 1, filled => 1, color => $color );
	# $mask->setpixel( x => $x1, y => $y1, color => 0 );
	# $dest->masked( mask => $mask );
    }
}

$dest->write( file => "dymaxion.tif" );
