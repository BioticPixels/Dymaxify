#!/usr/bin/perl

# Originally written by Schuyler D. Erle
# Edited by Biotic Pixels on 4 June 2015 22:07:58

# Converts an equirectangular TIFF map to a Dymaxion TIFF map.

use Imager;
use Imager::File::TIFF; # Install using "# env "ARCHFLAGS=-arch x86_64" cpan -i Image::File::TIFF" on OSX Yosemite ( https://rt.cpan.org/Public/Bug/Display.html?id=88039 ).
use Geo::Dymaxion;
use POSIX;
use strict;
use warnings;

# perl dymaxify3.pl [string] "input.tif" [string] "output.tif" [int] totalWidth [int] totalHeight [int] boundXMin [int] boundYMin [int] backgroundRed [int] backgroundGreen [int] backgroundBlue
# perl dymaxify3.pl "input.tif" "output.tif" 0 0 0 0 0 0 0

# Input image file path (must be an equirectangular projection).
my $commandLineFileInput = $ARGV[0];
# Output image file path.
my $commandLineFileOutput = $ARGV[1];
# Total size of combined sections of image in pixels, width and height.
my $commandLineTotalX = $ARGV[2]; # Width.
my $commandLineTotalY = $ARGV[3]; # Height.
# Coordinate bound of individual section in pixels.
my $commandLineBoundX = $ARGV[4]; # Minimum x within the combined image.
my $commandLineBoundY = $ARGV[5]; # Minimum y within the combined image.
# Background colours (0 to 255).
my $commandLineRed = $ARGV[6]; # Red.
my $commandLineGreen = $ARGV[7]; # Green.
my $commandLineBlue = $ARGV[8]; # Blue.

sub getLongTime {
    return strftime("%d %B %Y %H:%M:%S", localtime(time));
}

my $time; # Current time.

my $lastTime;
my $thisTime = time;
my $timeDifference;
my $hours;
my $minutes;
my $theTime;
sub difference {
    $theTime = @_[0]; # TODO Better way of writing this? …
    if ($theTime) {
        $lastTime = $theTime;
    } else {
        $lastTime = $thisTime;
    }
    $thisTime = time;
    $timeDifference = $thisTime - $lastTime;
    $hours = floor($timeDifference / 60 / 60);
    $timeDifference = $timeDifference - ($hours * 60 * 60);
    $minutes = floor($timeDifference / 60);
    $timeDifference = $timeDifference - ($minutes * 60);
    if ($timeDifference == 0) {
        $timeDifference = "<1";
    }
    # TODO Is the '\ \b' necessary, could it not be '$hours\hours' for example? …
    return "$hours\ \bhours $minutes\ \bminutes $timeDifference\ \bseconds";
}

# Open original image.
$time = getLongTime;
print "\n";
print "$time Opening image.\n";
$thisTime = time;
my $src = Imager->new;
$src->open( file => "$commandLineFileInput" ) # TODO Use command line argument for filename.
	or die $src->errstr;
$timeDifference = difference();
print "Done. +$timeDifference\n";
# Get the width and height of the original image.
my ($width, $height) = ($src->getwidth, $src->getheight);

# Generate Dymaxion coordinates from dimensions of the combined original image.
my $dymax = Geo::Dymaxion->new( $commandLineTotalX, $commandLineTotalY );

$time = getLongTime;
print "$time Setting up destination image.\n";

# Create the destination image filled with a colour.
my $dest = Imager->new( xsize => $commandLineTotalX, ysize => $commandLineTotalY );
$dest->box( xmin => 0,  ymin => 0, 
	    xmax => $commandLineTotalX, ymax => $commandLineTotalY,
	    color => [$commandLineRed, $commandLineGreen, $commandLineBlue, 0],
	    filled => 1 );

# TODO In order to do only part, the start and end equirectangular coordinates that are used in the loop would just need to be limited. The total combined original image dimensions would only be used by the Dymaxion coordinate convertion? … Done but has BUG Positive $commandLineBoundY values do not work …
# TODO Append to file then garbage collect? … Wouldn't necessarily be an append? … Unnecessary.
# TODO Limit the output bounds (output in sections for the entire image for each input image? … )? … Trim at set pixels, save, then overwrite on the next Dymaxion section/bounds … Not necessary.
# TODO Progress %? … Calculate number of pixels, divide by 100, count down that number of pixels in the loop (in the/for every x) and then print the percentage with a timestamp? … Done.
# TODO Add ETA? …

# Variables for progress counter.
my $imageArea = $width * $height;
my $imagePercent = $imageArea / 100; # How many pixels make up one percent of the image.
my $percentCount = $imagePercent; # Number of pixels of percentage decrimented on each pixels complete.
my $percentProgress = 0; # Percent done.
my $imageProgress = 0; # Number of pixels done.
my $percentTotal = 0; # Percentage progress.
my $progressString; # Progress output string.
my $superTime = time;
my $pixelCounterReset = 1000; # Set this to $imagePercent for per percent updates (integer percent updates)
my $pixelCounter = $pixelCounterReset; # Pixel count down, used for progress output which is done every time $pixelCounter reaches 0 or less.
my $red;
my $green;
my $blue;
my $alpha;

$timeDifference = difference;
$time = getLongTime;
print "Done. +$timeDifference\n$time Converting equirectangular map to Dymaxion map.\n";

# For every y coordinate starting from the bottom until it reaches the height of the original image.
for (my $y = 0; $y < $height; $y++) {
    # Calculate the current equirectangular lattitude based on the height of the original image.
    my $lat    = 90 - (($y + $commandLineBoundY) / $commandLineTotalY ) * 180;
    # For every x coordinate starting at the left until it reaches the width of the original image.
    for (my $x = 0; $x < $width; $x++) {
        # Calculate the current equirectangular longditude based on the width of the original image.
        my $lon    = (($x + $commandLineBoundX) / $commandLineTotalX ) * 360 - 180;
        # Generate the current Dymaxion lattitude and longditude x and y based on the equirectangular lattitude and longditude.
        my ($x1, $y1) = $dymax->plot( $lat, $lon );
        
        # Get the equirectangular pixel from the original image.
        my $color = $src->getpixel( x => $x, y => $y );

        # TODO What did this do?
        # Creates a circle with anti aliasing? …
        ($red, $green, $blue, $alpha) = $color->rgba(); # circle() does not like the $color object.
        # TODO Why is the radius of the circle 1.25? …
        # TODO Are the pixels (which are given as floats and not integers) interpolated? …
        $dest->circle( x =>  $x1, y => $y1, r => 1.25, aa => 1, filled => 1, color =>  [$red, $green, $blue] );
        
        # TODO Improve setting pixels? … Depends how circle() interprets float x and y values given to it dymax->plot(), does it round them or interpolate them? … circle() pseudo anti aliases the images, it would be better it it did not do this? … 
        
        # Display time and progress percentage.
        $imageProgress++;
        $percentCount--;
        $pixelCounter--;
        if ($pixelCounter == 0 || $percentCount <= 0) { # Display per $pixelCounter or on the percent (useful if $pixelCounter is big or the image is small).
            $pixelCounter = $pixelCounterReset;
            # If at a full percent enter time taken and a new line.
            if ($percentCount <= 0) {
                $percentCount = $imagePercent + $percentCount; # $percentCount might be minus because of $pixelCounter, so if it is, add the negative values to $percentCount.
                
                $timeDifference = difference;
                print " +$timeDifference\n";
            } else {
                # Clear percentage progress.
                print "\b" x length($progressString) if defined $progressString; # TODO Better way of updating the output? …
            }
            
            $percentTotal = ($imageProgress/$imageArea) * 100;
            $percentTotal = sprintf("%.3f", $percentTotal);
            $time = getLongTime;
            $progressString = "$time $percentTotal%";
            print "$progressString";
        }
    }
}

$timeDifference = difference;
print " +$timeDifference\n";

# Display overall time taken to process the image.
$timeDifference = difference($superTime);
$time = getLongTime;
print "Done. +$timeDifference\n$time Writing file.\n";

$dest->write( file => "$commandLineFileOutput", tiff_compression => 'lzw' )
	or die $dest->errstr;

$timeDifference = difference;
print "Done. +$timeDifference\n\n";
