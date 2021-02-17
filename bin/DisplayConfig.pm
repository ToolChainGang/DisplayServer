#!/usr/bin/perl
#
########################################################################################################################
########################################################################################################################
##
##      Copyright (C) 2020 Peter Walsh, Milford, NH 03055
##      All Rights Reserved under the MIT license as outlined below.
##
##  FILE
##
##      DisplayConfig.pm
##
##  DESCRIPTION
##
##      Read in the config file for the display server
##
##      (Placed here to reduce clutter in the main file)
##
##  DATA
##
##      ->{Valid}                       True if file exists and parsed correctly
##
##      ->{Subdirs}                     List of recognized sub-directories
##          ->{$Name}                       Name of subdir (ie - "SWid")
##              ->{Scale}                       Scale to apply for files found in subdir
##
##      ->{Exts}                        List of recognized extensions
##          ->{$Ext}                        Name of extension (ie - "pdf")
##              ->{Command}                     Command used to display file with that extension
##
##  FUNCTIONS
##
##      GetDisplayConfig()              Return hash of values from config file
##
########################################################################################################################
########################################################################################################################
##
##  MIT LICENSE
##
##  Permission is hereby granted, free of charge, to any person obtaining a copy of
##    this software and associated documentation files (the "Software"), to deal in
##    the Software without restriction, including without limitation the rights to
##    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
##    of the Software, and to permit persons to whom the Software is furnished to do
##    so, subject to the following conditions:
##
##  The above copyright notice and this permission notice shall be included in
##    all copies or substantial portions of the Software.
##
##  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
##    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
##    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
##    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
##    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
##    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##
########################################################################################################################
########################################################################################################################

package Site::DisplayConfig;
    use base "Exporter";

use strict;
use warnings;
use Carp;

use lib "$ENV{HOME}/DisplayServer/lib";

use Site::ParseData;

our @EXPORT  = qw(&GetDisplayConfig);       # Export by default

########################################################################################################################
########################################################################################################################
##
## Data declarations
##
########################################################################################################################
########################################################################################################################

$| = 1;         # Flush output immediately

# #
# # Subdirs we recognize
# #
# Subdir      SWid                    # Subdir name in /src/Display
#     Scale       Width               # One of [Width, Height, None, Both]
#
# Subdir      SHgt                    # Subdir name in /src/Display
#     Scale       Height              # One of [Width, Height, None, Both]
#
# #
# # Global: How to handle various extensions
# #
# Extension   pdf
#     Command "qpdfview %f"
#
# Extension   txt
#     Command "mousepad %f"
#
# Extension   jpg
#     Command "gpicview %f"
#
our $DisplayConfigFile = "$ENV{HOME}/DisplayServer/etc/DisplayServer.conf";

our $ConfigExtMatches = [
    {                      RegEx => qr/^\s*#/                   ,Action => Site::ParseData::SkipLine    }, # Skip Comments
    {                      RegEx => qr/^\s*Extension\s*(\w+)/i  ,Action => Site::ParseData::StartSection},
    { Name => "Ext"      , RegEx => qr/^\s*Extension\s*(\w+)/i  ,Action => Site::ParseData::AddVar},
    { Name => "Command"  , RegEx => qr/^\s*Command\s*(".*")/i   ,Action => Site::ParseData::AddQVar},
    { Name => "Scale"    , RegEx => qr/^\s*Scale\s*(".*")/i     ,Action => Site::ParseData::AddVar},
    ];

our $ConfigDirMatches = [
    {                      RegEx => qr/^\s*#/                   ,Action => Site::ParseData::SkipLine    }, # Skip Comments
    {                      RegEx => qr/^\s*Subdir\s*(\w+)/i     ,Action => Site::ParseData::StartSection},
    { Name => "Subdir"   , RegEx => qr/^\s*Subdir\s*(\w+)/i     ,Action => Site::ParseData::AddVar},
    { Name => "Command"  , RegEx => qr/^\s*Command\s*(".*")/i   ,Action => Site::ParseData::AddQVar},
    { Name => "Scale"    , RegEx => qr/^\s*Command\s*(".*")/i   ,Action => Site::ParseData::AddQVar},
    ];

########################################################################################################################
########################################################################################################################
#
# GetDisplayConfig - Set up a local config struct with all the information from the config file
#
# Inputs:      None.
#
# Outputs:     Hash of config file values
#
sub GetDisplayConfig {

    ####################################################################################################################
    #
    # GPIO information, from config file
    #
    return { Valid => 0 }
        unless -r $DisplayConfigFile;

    my $ConfigFile = Site::ParseData->new(Filename => $DisplayConfigFile, Matches  => $DisplayMatches);
    my $DisplayConfig = $ConfigFile->ParseFile();
    }
