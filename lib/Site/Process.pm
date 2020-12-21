#!/dev/null
#
########################################################################################################################
########################################################################################################################
##
##      Copyright (C) 2020 Peter Walsh, Milford, NH 03055
##      All Rights Reserved under the MIT license as outlined below.
##
##  FILE
##
##      Site::Process.pm
##
##  DESCRIPTION
##
##      Process - An object for managing external processes: TimeoutCommand() and BackgroundCommand()
##
##      ->TimeoutCommand($Cmd,$Timeout) will execute an external command, and call ErrorReboot if the command does
##        not complete within the timeout. This is useful for things like an external device which may take a
##        variable amount of time initialize and become ready, but which also may hang and could benefit from a
##        complete reboot. Cell modems and the AP libraries work that way.
##
##      ->BackgroundCommand($Cmd) will execute an external command in the background, and will return the PID of the
##        resulting process.
##
##      ->EndBackgroundCommand($PID) will kill the executing command. This is useful for processes that are
##        completely simple and don't need all the process management that perl/fork can supply.
##
##      The process system is specific for RasPi debugging. A call to ErrorReboot() will nominally reboot the
##        system in 60 seconds, but if a user is logged in the reboot will be delayed - on the assumption that
##        the logged-in user is working to improve the system (or wants to debug what went wrong). When all users
##        subsequently log out, the reboot then happens as normal.
##
##      The types of user that will prevent reboot can be configured:
##
##          AnyUsers    Any logged in users will prevent the reboot until those users log out
##          SSHUsers    Only SSH users will prevent the reboot, normal users will have no effect on the feature
##          NoUsers     Users will not prevent the reboot process. 
##
##  DATA
##
##      ->{TimedCommand}                    Currently executing timed command
##      ->{Timeout}                         Timeout value (secs) for timed command
##
##      ->{BackgroundCommands}              List of background commands we are currently managing
##          ->{PID}                         PID of individual command
##              ->{Command}                 Command currently running under $PID
##              ->{PID}                     PID of command (same as hash key)
##
##  FUNCTIONS
##
##      ->new(%Args)                        Make a new PNode with specified arguments
##
##      ->TimeoutCommand($Cmd,$Timeout)     Execute command with timeout
##
##      ->BackgroundCommand($CMD)           Execute command in background
##      ->EndBackgroundCommand($PID)        End command running in background
##      ->EndBackgroundCommands()           End all commands running in background
##
##      ->NoRebootUsers($Type)              Don't reboot on error if $Type users are logged in
##          Site::Process::AnyUsers             Any users (GUI and SSH) will prevent reboot
##          Site::Process::SSHUsers             SSH users (but not GUI) will prevent reboot
##          Site::Process::NoUsers              Reboot is not prevented by logged-in users
##
##      ->NumBlockingUsers($Type)           Number of reboot-blocking users currently logged in
##
##      ->Message($Msg)                     Print out a message to the user
##      ->ConsoleMessage($Msg)              Print out a message on the console
##
##  DERIVED MUST IMPLEMENT
##
##      None.
##
##  ISA
##
##      None.
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

package Site::Process;

use strict;
use warnings;
use Carp;

use POSIX ":sys_wait_h";

use Sys::Syslog qw(:standard :macros);

use Site::RasPiUtils;

our $VERSION = '2020.12_16';

########################################################################################################################
########################################################################################################################
##
## Data declarations
##
########################################################################################################################
########################################################################################################################

use constant DEFAULT_TIMEOUT => 60;         # Seconds for timed command timout, if not specified

use constant AnyUsers => 0;                 # Any logged-in users will stop reboot
use constant SSHUsers => 1;                 # SSH users, not GUI users
use constant NoUsers  => 2;                 # reboot is not prevented

########################################################################################################################
########################################################################################################################
#
# Site::Process - Generate a new process management object
#
# Inputs:   None.
#
# Outputs:  New process object
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = bless {}, $class;

    $self->{TimedCommand} = "";
    $self->{Timeout     } = 0;

    $self->{BackgroundCommands} = {}
    $self->{NoRebootUsers     } = AnyUsers;

    $SIG{ALRM} = sub { $self->Timeout  (); };
    $SIG{CHLD} = sub { $self->ChildExit(); };

    return $self;
    }


#######################################################################################################################
########################################################################################################################
##
## TimeoutCommand - Execute a command, with timeout. Reboot if command times out
##
## Inputs:      Command to execute (ie: "ifconfig")
##              Timeout for command, in seconds (DEFAULT: 60)
##
## Outputs:     Text response of command, if successful
##
## NOTE: Reboots the system on timeout, but not command fail.
##
sub TimeoutCommand {
    my $self              = shift;
    $self->{TimedCommand} = shift;
    $self->{Timeout     } = shift // DEFAULT_TIMEOUT;

    my $Rtnval;

    eval {
        alarm $self->{SysTimeout};

        $Rtnval = `$Command`;

        alarm 0;
        };

    $self->ErrorReboot("Error executing $Command ($!)")
        if $@;
        
    return $Rtnval;
    }


########################################################################################################################
########################################################################################################################
##
## Timeout - Process timeout of system command
##
## Inputs:      None (called as signal handler)
##
## Outputs:     None - reboots the system
##
sub Timeout {
    my $self = shift;

    $self->ErrorReboot("Timeout ($self->{Timeout} secs) executing $self->{TimedCommand}"); 
    }


########################################################################################################################
########################################################################################################################
##
## BackgroundCommand - Execute a system command in the background.
##
## Inputs:      System command to execute (ie: "ifconfig")
##
## Outputs:     PID of resulting process
##
sub BackgroundCommand {
    my $self    = shift;
    my $Command = shift;

    my $PID;
    exec $Command
        unless $PID = fork();

    #
    # Make note of the PID and child command, in case it exits and we need to print out an error msg
    #
    $self->{BackgroundCommands}{$PID}{Command} = $Command;
    $self->{BackgroundCommands}{$PID}{    PID} = $PID;

    $self->Message("BackgroundCommand $Command (PID $PID)");

    return $PID;
    }


########################################################################################################################
########################################################################################################################
##
## EndBackgroundCommand - Kill a background command
##
## Inputs:      PID of background command already started
##
## Outputs:     None.
##
sub EndBackgroundCommand {
    my $self = shift;
    my $PID  = shift;

    $self->ErrorReboot("PID $PID is not a background command")
        unless defined $self->{BackgroundCommands}{$PID};

    $self->Message("Stopping $self->{BackgroundCommands}{$PID}{Command} (PID $PID)");

    #
    # Remove the $BackgroundCommands{$PID} first, so we know tha tthe child exit is expected.
    #
    delete $BackgroundCommands{$PID};

    kill "KILL",$PID;
    }


########################################################################################################################
########################################################################################################################
##
## EndBackgroundCommands - Kill all currently running background commands
##
## Inputs:      None.
##
## Outputs:     None.
##
sub EndBackgroundCommands {
    my $self = shift;

    EndBackgroundCommand($_)
        foreach keys %{$self->{BackgroundCommands}};
    }

    
########################################################################################################################
########################################################################################################################
##
## ChildExit - Manage exit of background child process
##
## Inputs:      None (called as signal handler)
##
## Outputs:     None - reboots the system
##
sub ChildExit { 
    my $self = shift;
    my $PID  = waitpid(-1, WNOHANG);

    return
        if $PID == -1;      # == No child waiting

    return
        if $PID ==  0;      # == Children, none terminated

    my $Command = $self->{BackgroundCommands}{$PID}

    return                  # Ended by func call, exit expected.
        unless defined $Command;

    #
    # If there's no entry in the BackgroundProcess list for thie PID, then it means the
    #   child was a direct command (and not meant to be in the background).
    #
    # Returning is expected, so ignore those.
    #
    print "Command complete: $self->{TimedCommand}\n"               # Unnecessary, and messes up printed output
        if substr($self->{TimedCommand},0,10) ne "sudo sh -c";

    $self->ErrorReboot("Reboot due to command exit: $Command->{Command} (PID $PID)"); 
    }


########################################################################################################################
########################################################################################################################
##
## NoRebootUsers - Take note of which users will block reboot   
##
## Inputs:      Type of user that will block reboot (DEFAULT: Site::Process::AnyUser)
##
## Outputs:     None.
##
sub NoRebootUsers {
    my $self  = shift;
    my $Users = shift // AnyUsers;

    die "Process->NoRebootUsers($Users): BadArgument"
        unless $Users == AnyUsers ||
               $Users == SSHUsers ||
               $Users == NoUsers;

    $self->{NoRebootUsers} = $User;
    }


########################################################################################################################
########################################################################################################################
##
## ErrorReboot - Log an error, then reboot
##
## Inputs:      Message to log
##
## Outputs:     None - reboots the system
##
sub ErrorReboot {
    my $self     = shift;
    my $ErrorMsg = shift;

    $self->Message("",1);
    $self->Message("$ErrorMsg",1);

    if( $self->NumBlockingUsers() > 0 ) {
        $self->Message("No reboot, due to user login.",1);
        $self->Message("",1);
        $self->WatchUsers();
        }

    $self->Message("Critical error - rebooting in 60 seconds.",1);
    $self->Message("",1);
    $self->Message("",1);

    sleep(60);

    if( $self->NumBlockingUsers() > 0 ) {
        $self->Message("No reboot, due to user login.",1);
        $self->Message("",1);
        $self->WatchUsers();
        }

    $self->Message("Rebooting ",1);

    exec "sudo reboot";
    }


########################################################################################################################
########################################################################################################################
##
## WatchUsers - Watch for user logouts, then reboot the system
##
## Inputs:      None.
##
## Outputs:     None. Will reboot when users log out
##
## NOTE: If the user doesn't fix the problem but logs out, the system would never reboot. Keep watching
##         the user logins, and if they go to zero, reinstate the reboot timeout.
##
sub WatchUsers {
    my $self = shift;

    while(1) {
        sleep 10;

        $self->ErrorReboot("Reinstating reboot timer due to user logout.")
            unless $self->NumBlockingUsers();
        }
    }


########################################################################################################################
########################################################################################################################
##
## NumBlockingUsers - Return number of boot-blocking users on the system
##
## Inputs:      None.
##
## Outputs:     Number of logged-in users that will block reboot
##
sub NumBlockingUsers {
    my $self = shift;

    return 0
        if $self->{NoRebootUsers} == NoUsers;

    return NumSSHUsers()
        if $self->{NoRebootUsers} == SSHUsers;
        
    return NumUsers();
    }


########################################################################################################################
########################################################################################################################
##
## Message - Show message to the user
##
## Inputs:      Msg        Message to print
##              Fail       If message indicates a failure, (==1) print in Red, else (==0) print in Green
##
## Outputs:  1 => So that user can call exit with return value
##
sub Message {
    my $self = shift;
    my $Msg  = shift // "";
    my $Fail = shift // 0;

    #
    # Put the message in 3 places: System log, boot screen, and program log (captured from STDOUT)
    #
    $self->ConsoleMessage($Msg,$Fail);
    syslog(LOG_CRIT,$Msg);

    print "$Msg\n";

    return 1;
    }


########################################################################################################################
########################################################################################################################
##
## ConsoleMessage - Show message in boot screen
##
## Inputs:      Msg        Message to print
##              Fail       If message indicates a failure, (==1) print in Red, else (==0) print in Green
##
## Outputs:  None.
##
sub ConsoleMessage {
    my $self = shift;
    my $Msg  = shift;
    my $Fail = shift // 0;

    return
        unless IAmRoot();

    #
    # Colors for boot console messages
    #
    my $RED   = '\033[0;31m';
    my $GREEN = '\033[0;32m';
    my $NC    = '\033[0m';          # No Color

    if( $Fail ) { $self->TimeoutCommand("sudo sh -c 'echo \"[${RED}FAILED${NC}] $Msg\"   >/dev/tty0'"); }
    else        { $self->TimeoutCommand("sudo sh -c 'echo \"[${GREEN}  OK  ${NC}] $Msg\" >/dev/tty0'"); }
    }



#
# Perl requires that a package file return a TRUE as a final value.
#
1;
