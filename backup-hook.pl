#!/usr/bin/perl
use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use Config::Simple;
use File::Slurp;

# Define the path to the script and then to the .env file
my $script_dir = dirname(abs_path(__FILE__));
my $env_path = "$script_dir/.env";

# Load the .env file using Config::Simple
my $cfg = Config::Simple->new($env_path) or die "Cannot load .env file: $!";
my $auth_token = $cfg->param('auth_token') || '';
my $webhook_url = $cfg->param('webhook_url') || '';

# Path to the file for storing successful backups
my $success_file = '/tmp/successful_backups.log';

# Retrieve script arguments
my $phase = shift;
chomp(my $hostname = `hostname`);
my $storeid = $ENV{STOREID} || '';

# Process phase
if ($phase eq 'job-init' || $phase eq 'job-start' || $phase eq 'job-end' || $phase eq 'job-abort') {
    if ($phase eq 'job-end' || $phase eq 'job-abort') {
        # Load the content of the successful backups file for notification
        my $message = "Backup successfully completed for the following VM/LXC:\n";
        if (-e $success_file) {
            $message .= read_file($success_file);
            unlink $success_file;
        }
        send_ntfy_notification($hostname, $storeid, 'white_check_mark', $message);
    }

} elsif ($phase eq 'backup-start' || $phase eq 'backup-end' || $phase eq 'backup-abort') {
    my ($mode, $vmid) = @ARGV;
    my $vmtype = $ENV{VMTYPE} || 'unknown';

    # Retrieve the VM name
    my $vm_name = ($vmtype eq 'qemu') ? `qm config $vmid | awk '/^name:/ {print \$2}'`
                : ($vmtype eq 'lxc') ? `pct config $vmid | awk '/^hostname:/ {print \$2}'`
                : 'unknown';
    chomp $vm_name;

    if ($phase eq 'backup-abort') {
        # Send an error message
        my $error_message = extract_error_message($vmtype, $vmid);
        my $message = "Error during backup of $vmid ($vm_name):\n$error_message";
        send_ntfy_notification($hostname, $storeid, 'x', $message);
    } elsif ($phase eq 'backup-end') {
        # Successful backup, add to the file
        open my $fh, '>>', $success_file or die "Cannot open file $success_file for writing: $!";
        print $fh "$vmid ($vm_name)\n";
        close $fh;
    }
}

# Function to retrieve error message from log
sub extract_error_message {
    my ($vmtype, $vmid) = @_;
    my $logfile = "/var/log/vzdump/${vmtype}-${vmid}.log";
    return "Log file not found" unless -e $logfile;
    my @lines = read_file($logfile);
    # Return the first line containing "ERROR"
    foreach my $line (@lines) {
        if ($line =~ /ERROR:?\s*(.*)/) {
            return $1;
        }
    }
    return "Unknown error";
}

# Function to send a notification
sub send_ntfy_notification {
    my ($hostname, $storeid, $tags, $message) = @_;
    my $curl_command = "curl -s -o /dev/null -w '%{http_code}' "
                 . "-H \"Authorization: Bearer $auth_token\" "
                 . "-H \"Icon: https://avatars.githubusercontent.com/u/2678585?s=200&v=4\" "
                 . "-H \"Title: $hostname: Backup to $storeid\" "
                 . "-H \"Tags: $tags\" "
                 . "-d \"$message\" $webhook_url";
    system($curl_command);
}
exit(0);
