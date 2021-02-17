#!/dev/null
########################################################################################################################
########################################################################################################################
##
##      Copyright (C) 2020 Peter Walsh, Milford, NH 03055
##      All Rights Reserved under the MIT license as outlined below.
##
##  FILE
##
##      Site::WinInfo.pm
##
##  DESCRIPTION
##
##      Return various process window information
##
##  DATA
##
##      None.
##
##  FUNCTIONS
##
##      ($W, $H) = GetScreenSize()          Return screen size
##
##      GetWinInfo()                        Return hash of window information
##          ->{$PID}                            Process ID of window
##              ->{PID}                             Process ID (same as hash key)
##              ->{WID}                             Window  ID of process
##              ->{Desktop}                         Desktop process is running on
##              ->{UL}                              UL of display window
##              ->{UR}                              UR of display window
##              ->{W}                               Width  of display window
##              ->{H}                               Height of display window
##              ->{Sysname}                         System name
##              ->{Title}                           Title 1st word
##
##      WaitForWindow($PID)                 Wait for PID window to open up
##
##      MoveWin($WID, $X, $Y)               Move window to position
##      SizeWin($WID, $X, $Y)               Resize window
##
##      MaxWin($WID)                        Make window full screen
##      RaiseWin($WID)                      Bring the window forward
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

package Site::WinInfo;
    use base "Exporter";

use strict;
use warnings;
use Carp;

use Site::ParseData;

our @EXPORT  = qw(&GetWinInfo
                  &GetDisplaySize
                  &WaitForWindow
                  &MaxWin
                  &MoveWin
                  &SizeWin);     # Export by default

########################################################################################################################
########################################################################################################################
##
## Data declarations
##
########################################################################################################################
########################################################################################################################

#
# Window ID  WS PID    UL   UR   W    H    Sysname     Title
#
# 0x00e0001c -1 972    0    0    1280 36   raspberrypi panel
# 0x00c00003 -1 975    0    0    1280 1024 raspberrypi pcmanfm
# 0x01600008  0 4730   323  335  640  480  raspberrypi puzzle-0.jpeg (850x1100) 40%
# 0x01800003  0 4736   4    96   640  480  raspberrypi Notes.txt - Mousepad
# 0x01400006  0 4703   0    92   1280 960          N/A matrixcookbook - qpdfview
#
our $WinInfoCmd = "wmctrl -p -G -l";
our $WinMatches = [
    {                     RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*(\d*)\s*\d*\s*\d*\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::StartSection},
    { Name => "WID"     , RegEx  => qr/^\s*(0x[[:xdigit:]]{8})\s*-?\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "Desktop" , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*(-?\d*)\s*\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "PID"     , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*(\d*)\s*\d*\s*\d*\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "UL"      , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*(\d*)\s*\d*\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "UR"      , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*\d*\s*(\d*)\s*\d*\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "W"       , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*\d*\s*\d*\s*(\d*)\s*\d*\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "H"       , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*(\d*)\s*\w*\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "Sysname" , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*(\w*)\s*.*$/,Action => Site::ParseData::AddVar},
    { Name => "Title"   , RegEx  => qr/^\s*0x[[:xdigit:]]{8}\s*-?\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\d*\s*\w*\s*(.*)$/,Action => Site::ParseData::AddVar},
    ];

########################################################################################################################
########################################################################################################################
#
# GetWinInfo - Return hash of window information in system
#
# Inputs:   None.
#
# Outputs:  Hash of window information
#
sub GetWinInfo {

    my $WinParse = Site::ParseData->new(Matches => $WinMatches);
    my $WinInfo  = $WinParse->ParseCommand($WinInfoCmd);

use Data::Dumper;
print Data::Dumper->Dump([$WinInfo],[qw(WinInfo)]);

    return $WinInfo;
    }


########################################################################################################################
########################################################################################################################
#
# GetDisplaySize - Return display window size
#
# Inputs:   None.
#
# Outputs:  ($W, $H) Width and height of display
#
sub GetDisplaySize {

    my $SizeText = `xdpyinfo | grep dimensions`;

    chomp $SizeText;

    #
    #  dimensions:    1280x1024 pixels (338x270 millimeters)
    #
    my ($W, $H) = $SizeText =~ m/\s*dimensions:\s*(\d*)x(\d*) pixels/;

print "Display: ${W}x${H}\n";

    return ($W,$H);
    }


########################################################################################################################
########################################################################################################################
#
# WaitForWindow - Wait until the window of a specified PID is visible
#
# Inputs:   PID of process opening window
#
# Outputs:  WindowID of that PID
#
sub WaitForWindow {
    my $PID = shift;

    my $WID = 0;

    until( $WID ) {
        $WID = `xdotool search -sync -all -onlyvisible --pid $PID`;
        }

    return $WID
    }


########################################################################################################################
########################################################################################################################
#
# MoveWin - Move specified window to position
#
# Inputs:   ID of window to move
#           X, Y position to move to
#
# Outputs:  None.
#
sub MoveWin {
    my $WindowID = shift;
    my $X        = shift;
    my $Y        = shift;

    `xdotool windowmove $WindowID $X, $Y`;
    }


########################################################################################################################
########################################################################################################################
#
# SizeWin - Set size of specified window
#
# Inputs:   ID of window to move
#           W, H new size
#
# Outputs:  None.
#
sub SizeWin {
    my $WindowID = shift;
    my $W        = shift;
    my $H        = shift;

    `xdotool windowsize $WindowID $W, $H`;
    }


########################################################################################################################
########################################################################################################################
#
# MaxWin - Maximize specified window
#
# Inputs:   ID of window to modify
#
# Outputs:  None.
#
sub MaxWin {
    my $WindowID = shift;

    #
    # Sending F11 seems to do what we want. Sending "windowmaximize" and "windowsetsize" commands
    #   (and various related forms) are either ignored or aren't true full-screen commands.
    #
    # Perhaps this should be revisited at some later date.
    #
    `xdotool key $WindowID F11`;
    }


########################################################################################################################
########################################################################################################################
#
# RaiseWin - Bring a window forward
#
# Inputs:   ID of window to raise
#
# Outputs:  None.
#
sub RaiseWin {
    my $WindowID = shift;

    `xdotool windowraise $WindowID`;
    }


#
# Perl requires that a package file return a TRUE as a final value.
#
1;
