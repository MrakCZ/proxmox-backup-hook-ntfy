### Introduction
I present to you two versions of a handy backup notification script for Proxmox! One is written in shell, and the other in Perl—choose whichever suits your preferences best! Both scripts use the ntfy service with the curl command, ensuring all notifications reach you easily and securely with authorization provided by a token created in ntfy.

Notifications are sent for both successful backups and those that didn’t go as planned. If an error occurs, you’ll receive an immediate notification with details from the log, so you know right away what went wrong. The scripts then patiently wait until the entire backup process completes to send a comprehensive list of all successfully completed backups. They handle errors and manual interruptions, sending a list of completed backups along with information on which backup was interrupted. In short, nothing slips by (hopefully)!
It's not the best, but it works (most of the time).
### Requirements:
- Proxmox
- Ntfy with a created authorization token and a topic to which you’re subscribed.
- For the Perl version, install the modules `Config::Simple` and `File::Slurp`:
```bash
apt install libconfig-simple-perl libfile-slurp-perl
```
- A .env file in the same directory as the script. If located elsewhere, modify the script accordingly! The .env file content should include:

```plaintext
# Authorization token for notifications
auth_token="tk_lwjldwk908adasgw865dask"

# URL for sending notifications
webhook_url="https://notifications.your-domain.com/proxmox_backup"
```
### Setup
Choose the script that works best for you, copy it into your own file (or clone the entire repository), for example, into `/root/scripts/backup-hook.sh` or `/root/scripts/backup-hook.pl`. Set the selected script as executable with:

```bash
chmod +x /root/scripts/backup-hook.sh
```
or
```bash
chmod +x /root/scripts/backup-hook.pl
```
Edit `jobs.cfg` or `vzdump.conf` to trigger the script at the start of the backup process:

```bash
nano /etc/pve/jobs.cfg
```
Example:
```bash
vzdump: backup-1a2b3c4d5-0a1b
        schedule mon,wed,fri
        all 1
        enabled 1
        exclude 200
        fleecing 0
        mode snapshot
        node proxmox-test
        notes-template {{guestname}}
        notification-mode notification-system
        script /root/scripts/backup-hook.sh
        storage test_backup
```
or 
```bash
nano /etc/vzdump.conf
```
Example:
```bash
# vzdump default settings

#tmpdir: DIR
#dumpdir: DIR
#storage: STORAGE_ID
#mode: snapshot|suspend|stop
#bwlimit: KBPS
#performance: [max-workers=N][,pbs-entries-max=N]
#ionice: PRI
#lockwait: MINUTES
#stopwait: MINUTES
#stdexcludes: BOOLEAN
#mailto: ADDRESSLIST
#prune-backups: keep-INTERVAL=N[,...]
script: /root/scripts/backup-hook.sh
#exclude-path: PATHLIST
#pigz: N
#notes-template: {{guestname}}
#pbs-change-detection-mode: legacy|data|metadata
#fleecing: enabled=BOOLEAN,storage=STORAGE_ID
```
That's it!
