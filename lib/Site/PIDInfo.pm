#!/dev/null
########################################################################################################################
########################################################################################################################
##
##      Copyright (C) 2020 Peter Walsh, Milford, NH 03055
##      All Rights Reserved under the MIT license as outlined below.
##
##  FILE
##
##      Site::PIDInfo.pm
##
##  DESCRIPTION
##
##      Return various PID information
##
##  DATA
##
##      None.
##
##  FUNCTIONS
##
##      GetPIDInfo($PID)                Return info about PID (DEFAULT: Current PID)
##          ->{Flags}                       Flags (Root, Forked, Executed)
##          ->{UID}                         UID for process
##          ->{PID}                         PID  for process
##          ->{PPID}                        PPID for process
##          ->{Priority}                    Priority
##          ->{NI}                          Nice value
##          ->{VSZ}                         Virtual memory size in KiB
##          ->{RSS}                         Physical memory size
##          ->{WCHAN}                       Wait channel (address in kernel where waiting)
##          ->{STAT}                        Status: Z=Zombie, S=Sleeping R=Running
##          ->{TTY}                         Controlling terminal
##          ->{TIME}                        Cumulative CPU time
##          ->{Command}                     Command process is executing
##          ->{Args}                        Arguments given to command
##          ->{Children}[]                  Array of child PIDs
##
##      GetChildPIDs($PPID)             Return array of children PIDs of PID
##          ->[]                            Array of child PIDs
##
##      $ChildPID = WaitForChild($PPID) Wait until any child of process is spawned
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

package Site::PIDInfo;
    use base "Exporter";

use strict;
use warnings;
use Carp;

use Site::ParseData;

our @EXPORT  = qw(&GetPIDInfo
                  &GetChildPIDs
                  &WaitForChild);     # Export by default

########################################################################################################################
########################################################################################################################
##
## Data declarations
##
########################################################################################################################
########################################################################################################################

#
# F   UID   PID  PPID PRI  NI    VSZ   RSS WCHAN  STAT TTY        TIME COMMAND
# 5  1000 22353 22346  20   0  12240  3520 -      S    ?          0:00 sshd: pi@pts/3
#
use constant PS_FLAGS => 0;
use constant PS_UID   => 1;
use constant PS_PID   => 2;
use constant PS_PPID  => 3;
use constant PS_PRI   => 4;
use constant PS_NI    => 5;
use constant PS_VSZ   => 6;
use constant PS_RSS   => 7;
use constant PS_WCHAN => 8;
use constant PS_STAT  => 9;
use constant PS_TTY   => 10;
use constant PS_TIME  => 11;
use constant PS_CMD   => 12;
use constant PS_ARGS  => 13;

########################################################################################################################
########################################################################################################################
#
# GetPIDInfo - Return PID information
#
# Inputs:   PID of interest
#
# Outputs:  Hash of PID info
#
sub GetPIDInfo {
    my $PID = shift // $$;

    my @PSLines = `ps -fxl`;

    my $PIDInfo = { Children => [] };

    foreach my $PSLine (@PSLines) {

        chomp $PSLine;

        next
            if $PSLine =~ m/PPID/;      # Skip header line

        my @PSInfo = split /\s+/,$PSLine;

        next
            unless $PSInfo[PS_PID ] == $PID or
                   $PSInfo[PS_PPID] == $PID;

        if( $PSInfo[PS_PPID] == $PID ) { push @{$PIDInfo->{Children}},$PSInfo[PS_PID]; }
        else {
            $PIDInfo->{Flags}   = shift @PSInfo;
            $PIDInfo->{UID}     = shift @PSInfo;
            $PIDInfo->{PID}     = shift @PSInfo;
            $PIDInfo->{PPID}    = shift @PSInfo;
            $PIDInfo->{Pri}     = shift @PSInfo;
            $PIDInfo->{NI}      = shift @PSInfo;
            $PIDInfo->{VSZ}     = shift @PSInfo;
            $PIDInfo->{RSS}     = shift @PSInfo;
            $PIDInfo->{WCHAN}   = shift @PSInfo;
            $PIDInfo->{STAT}    = shift @PSInfo;
            $PIDInfo->{TTY}     = shift @PSInfo;
            $PIDInfo->{TIME}    = shift @PSInfo;
            $PIDInfo->{Command} = shift @PSInfo;
            $PIDInfo->{Args}    = [ @PSInfo ];
            }
        }

    return $PIDInfo;
    }


########################################################################################################################
########################################################################################################################
#
# GetChildPIDs - Return child PIDs of specified PID
#
# Inputs:   PID of parent process
#
# Outputs:  [Ref to] Array of child PIDs
#
sub GetChildPIDs {
    my $ParentPID = shift // $$;

    my $Info = GetPIDInfo($ParentPID);

    return $Info->{Children};
    }


########################################################################################################################
########################################################################################################################
#
# WaitForChild - Wait until a child PID of parent is visible
#
# Inputs:   PID of parent process
#
# Outputs:  First child seen of parent.
#
# NOTE: Parent might spawn multiple children, this function only returns 1st seen.
#
sub WaitForChild {
    my $ParentPID = shift // $$;

    while(1) {

        my $ChildPIDs = GetChildPIDs($ParentPID);

        return $ChildPIDs->[0]
            if @{$ChildPIDs};

        sleep 1;
        }
    }



#
# Perl requires that a package file return a TRUE as a final value.
#
1;
