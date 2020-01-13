#!/bin/bash
# Author: Ray Herbig, Jim Sloan
# Date: 2017-02-14
# Updated: 2017-03-09 - jsloan - added additional fixes for pam.d and /etc/cron.*, fixed a couple of issues with audit rules, added umask fix (commented out due to possible issues with umask), 
# 						added additional fstab fixes that may exist if separate mounts, added additional sshd_config fixes, added useradd inactivity configuration
#						added net.ipv4.conf fixes

# Add to Path just in case this is started somehow with no path so that certain tools will work
# such as pidof, service, systemctl, sed, grep, awk, mount, chown, chmod, etc
PATH=/sbin:/bin:$PATH

PID=$(pidof systemd)

RHELVER=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release) | cut -f1 -d.)

function RestartService {
	ServiceToRestart=$1
	if [ -z $PID ]
	then
		service $ServiceToRestart restart
	else
		systemctl restart $ServiceToRestart
	fi
}

function AddToFile {
	LineToAdd=$1
	FileToAddTo=$2
	grep "${LineToAdd//-/\\-}" /etc/audit/rules.d/audit.rules > /dev/null
	if [ $? -ne 0 ]
	then
		echo "$LineToAdd" >> "$FileToAddTo"
	fi
}

# Fstab
echo "setting nosuid, nodev, and noexec on /home and nosuid, nodev on /tmp"
cp -p /etc/fstab /etc/fstab.backup.$(date +%Y%m%d)

if mountpoint -q /home
then
	sed -i -e "/\/home.*nfs.*,nodev/! s/\/home.*nfs.*defaults/&,nodev/" /etc/fstab
	mount -o remount /home
fi
if mountpoint -q /tmp
then
	# Need to review modifying of /tmp to noexec as it will cause vmware tool install/upgrade to fail so only implementing the nodev and nosuid
	#sed -i -e "/\/tmp.*tmpfs.*nosuid/! s/^tmpfs.*\/tmp.*tmpfs.*defaults/&,nosuid/;/\/tmp.*tmpfs.*nodev/! s/^tmpfs.*\/tmp.*tmpfs.*defaults/&,nodev/;/\/tmp.*tmpfs.*noexec/! s/^tmpfs.*\/tmp.*tmpfs.*defaults/&,noexec/" /etc/fstab
	sed -i -e "/\/tmp.*tmpfs.*nosuid/! s/^tmpfs.*\/tmp.*tmpfs.*defaults/&,nosuid/;/\/tmp.*tmpfs.*nodev/! s/^tmpfs.*\/tmp.*tmpfs.*defaults/&,nodev/" /etc/fstab
	mount -o remount /tmp
fi
if [ $RHELVER -lt 7 ]
then
	## /dev/shm can only be managed via fstab on RHEL 6 and less, not on RHEL 7
	## nodev and nosuid are handled by the above tmpfs fix, only have to fix for noexec here.
	sed -i -e "/\/tmp.*\/dev\/shm.*noexec/! s/^tmpfs.*\/tmp.*\/dev\/shm.*defaults/&,noexec/" /etc/fstab
	mount -o remount /dev/shm
fi

# World writeable dirs
echo "setting sticky bit on world writeable directories (/opt/CA)"
if [ -d /opt/CA ]
then
	chmod +t /opt/CA/SharedComponents/cai18n
	chmod +t /opt/CA/SharedComponents/csutils/log
	chmod +t /opt/CA/SharedComponents/ID
	chmod +t /opt/CA/SharedComponents/tmp
fi
echo "setting sticky bit on additional world writeable directories found"
#this needs to be validated before running.
#DIRS=$(PARTs=`/bin/df --local -P 2>/dev/null | /bin/awk 'NR != 1  {$1="";$2="";$3="";$4="";$5="";gsub("^[[:space:]]+/","/",$0);print $0}' 2>/dev/null`; SaveIFS=$IFS;IFS=`/bin/echo -e "\n\b"`; for PART in $PARTs; do /usr/bin/find "$PART" -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -ls 2>/dev/null | /bin/awk '{a=$3; gsub("^[^/]*/","/",$0); print a, $0}'; done; )
#for d in $DIRS
#do
#	chmod +t $d
#done

# Ntp
echo "restricting ntp"
cp -p /etc/ntp.conf /etc/ntp.conf.backup.$(date +%Y%m%d)
cp -p /etc/sysconfig/ntpd /etc/sysconfig/ntpd.backup.$(date +%Y%m%d)
sed -i -e '/restrict default/ s/\(restrict default\).*/\1 kod nomodify nopeer notrap noquery/' /etc/ntp.conf
sed -i -e '/restrict -6/h; ${x;s/restrict -6//;{g;tF};a\' -e 'restrict -6 default kod nomodify nopeer notrap noquery' -e '};:F;s/restrict -6.*/restrict -6 default kod nomodify nopeer notrap noquery/g;' /etc/ntp.conf
sed -i -e "s/server 0.rhel.*/server 10.30.21.120/" -e "s/server.*rhel.*//g" /etc/ntp.conf
sed -i -e '/OPTIONS=/ s@.*OPTIONS=.*@OPTIONS="-u ntp:ntp -p /var/run/ntpd.pid"@' /etc/sysconfig/ntpd

# Boot.log
echo "setting boot.log permissions"
chmod 600 /var/log/boot.log

# Audit
echo "setting audit rules"
cp -p /etc/audit/rules.d/audit.rules /etc/audit/rules.d/audit.rules.backup.$(date +%Y%m%d%H%M%S)
STARTLEN=$(wc -l /etc/audit/rules.d/audit.rules | cut -f1 -d ' ')

AddToFile "-a exit,always -F arch=b32 -S sethostname -S setdomainname -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b32 -S clock_settime -k time-change" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change" /etc/audit/rules.d/audit.rules
AddToFile "-a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S clock_settime -k time-change" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=500 -F auid!=4294967295 -k perm_mod" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S init_module -S delete_module -k modules" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S mount -F auid>=500 -F auid!=4294967295 -k mounts" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F path=/usr/sbin/mount.nfs -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F path=/usr/bin/ksu -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F path=/usr/bin/screen -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" /etc/audit/rules.d/audit.rules
AddToFile "-a always,exit -F path=/opt/CA/SharedComponents/csutils/bin/casrvc -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" /etc/audit/rules.d/audit.rules
AddToFile "-w /sbin/insmod -p x -k modules" /etc/audit/rules.d/audit.rules
AddToFile "-w /sbin/rmmod -p x -k modules" /etc/audit/rules.d/audit.rules
AddToFile "-w /sbin/modprobe -p x -k modules" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/group -p wa -k identity" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/gshadow -p wa -k identity" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/shadow -p wa -k identity" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/passwd -p wa -k identity" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/opasswd -p wa -k identity" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/hosts -p wa -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/issue -p wa -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/issue.net -p wa -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/localtime -p wa -k time-change" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/sudoers -p wa -k scope" /etc/audit/rules.d/audit.rules
AddToFile "-w /etc/sysconfig/network -p wa -k system-locale" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/btmp -p wa -k session" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/wtmp -p wa -k session" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/utmp -p wa -k session" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/faillog -p wa -k logins" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/lastlog -p wa -k logins" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/tallylog -p wa -k logins" /etc/audit/rules.d/audit.rules
AddToFile "-w /var/log/sudo.log -p wa -k actions" /etc/audit/rules.d/audit.rules

## following -e 2 should already exist and not need to be put into /etc/audit/rules.d/audit.rules, but is missing on some systems.  Don't know where it should come from initially yet.
grep "-e 2" /etc/audit/audit.rules > /dev/null
if [ $? -ne 0 ]
then
	echo "-e 2" >> /etc/audit/rules.d/audit.rules
fi

# Add suid cmds to audit.rules
echo "adding suid cmds to audit rules"
CMDS=$(FileNames=`/usr/bin/find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null`; \
       if [ -n "$FileNames" ]; then for FileName in $FileNames;\
       do Regex="`/bin/echo $FileName | /bin/sed 's/[\.\/]/\\\&/g'`";\
       IsExisted=`/sbin/auditctl -l 2>/dev/null\
       |/bin/awk '$0 ~ /^[[:space:]]*LIST_RULES[[:space:]]*:[[:space:]]*exit,always/ && $0 ~ /[[:space:]]watch='"$Regex"'[[:space:]]+/ && $0 ~ /[[:space:]]perm=[[:graph:]]*x[[:graph:]]*[[:space:]]+/ && $0 ~ /[[:space:]]auid>=500[[:space:]]+/ && $0 ~ /[[:space:]]f24!=0[[:space:]]+/ {print $0}'`;\
       if [ -z "$IsExisted" ]; then /bin/echo "$FileName"; fi; done;fi)

for i in $(echo $CMDS)
do
   AddToFile "-a always,exit -F path=${i} -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged" /etc/audit/rules.d/audit.rules
done

## If we added any rules, add a comment before the rules with the date of addition
ENDLEN=$(wc -l /etc/audit/rules.d/audit.rules | cut -f1 -d ' ')
if [ $ENDLEN -gt $STARTLEN ]
then
	sed -i "${STARTLEN}a\# Added by tripwire remediation $(date +%Y-%m-%d\ %H:%M:%S)" /etc/audit/rules.d/audit.rules
fi


# Implement change.  Cannot use systemctl to restart auditd on RHEL7, must be restarted using service instead
echo "restarting auditd"
service auditd restart

# Ssh
echo "restricting sshd to disable X11Fowarding, 300 second timeout and loglevel to INFO"
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
# Leaving this one in here, but it may not be a good idea.  Also fixed it so if there is no commented out X11Fowarding no, it will add one.
sed -i -e 's/^X11Forwarding yes/#X11Forwarding yes/' -e '/X11Forwarding no/h; ${x;s/X11Forwarding no//;{g;tF};a\' -e 'X11Forwarding no' -e '};:F;s/.*X11Forwarding no.*/X11Forwarding no/g;' /etc/ssh/sshd_config 
# Fixed next 2 lines so they would change any settings to the proper ones, not just specific invalid settings.
sed -i -e 's/ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i -e 's/ClientAliveCountMax.*/ClientAliveCountMax 0/' /etc/ssh/sshd_config
sed -i -e 's/LogLevel.*/LogLevel INFO/' /etc/ssh/sshd_config
sed -i -e 's/^Ciphers.*/Ciphers aes128-ctr,aes192-ctr,aes256-ctr/' /etc/ssh/sshd_config
sed -i -e '/#.*Ciphers and keying/{a\Ciphers aes128-ctr,aes192-ctr,aes256-ctr' -e '$!{n;/^Ciphers aes128-ctr,aes192-ctr,aes256-ctr$/d}}' /etc/ssh/sshd_config 
sed -i -e 's/^MaxAuthTries.*/MaxAuthTries 4/' /etc/ssh/sshd_config
sed -i -e '/#.*MaxAuthTries/{a\MaxAuthTries 4' -e '$!{n;/^MaxAuthTries 4/d}}' /etc/ssh/sshd_config 
sed -i -e '/kexalgorithms/h; ${x;s/kexalgorithms//;{g;tF};a\' -e 'kexalgorithms diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1' -e '};:F;s/kexalgorithms.*/kexalgorithms diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1/g;' /etc/ssh/sshd_config
sed -i -e '/DSAAuthentication.*/d' /etc/ssh/sshd_config
sed -i -e 's/^\(HostKey.*ssh_host_dsa_key.*\)/#\1/' /etc/ssh/sshd_config
# Edit /etc/init.d/sshd (if exists) to not create DSA keys
if [ -f /etc/init.d/sshd ]
then
	# if AUTOCREATE_SERVER_KEYS doesn't exist as a var in the script, then add it after the PID_FILE var
	grep "AUTOCREATE_SERVER_KEYS=" /etc/init.d/sshd > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		sed -i -e '/PID_FILE=/a AUTOCREATE_SERVER_KEYS="RSAONLY"' /etc/init.d/sshd
	fi
fi
# Remove DSA keys
rm -f /etc/ssh/*_dsa_key*
# Implement change
RestartService sshd

# Group
cp -p /etc/group /etc/group.backup.$(date +%Y%m%d)
sed -i -e '/wheel:x:10:.*root.*/b;s/wheel:x:10:/&root,/;s/\(wheel:.*\),$/\1/;' /etc/group

## Fix files with no owners
#chown root:qualyssvcp /var/db/sudo/qualyssvcp 2> /dev/null
#chown addmdiscovery2:addmdiscovery2 /var/addmdiscovery2/.bash_history 2> /dev/null

## Fix /etc/gshadow and /etc/shadow permissions
echo "fix /etc/gshadow and /etc/shadow permissions"
chmod 400 /etc/gshadow
chmod 000 /etc/shadow

## Syslog to ArcSight Servers.   Perform this manually when given ArcSight server parameters.
#cp -p /etc/rsyslog.conf /etc/rsyslog.conf.backup.$(date +%Y%m%d)
#echo '*.* @ip_from_security' >> /etc/rsyslog.conf
# Implement change
#RestartService rsyslog

## Fix syslog/rsyslog Log File permissions
echo "fix syslog/rsyslog log file permissions"
for f in $(awk -F "#" '$1 !~ /^[[:space:]]*\$/ && $1 !~ /\*[[:space:]]*$/ && $1 !~ /^[[:space:]]*$/{ split($1,a," "); gsub(/-/,"",a[2]); if(a[2] !~ /^@/ && a[2] ~ /^[[:space:]]*\//){ print a[2];} }' /etc/rsyslog.conf 2>/dev/null); do chown root:root $f;chmod u-x,og-rwx $f;done

## Fix user inactivity settings to 35 day or less inactivity to lock user out.  Should only affect non eTrust or IdM systems
echo "fix user inactivity settings"
useradd -D -f 35

## Fix pam.d issues. 
echo "fix pam.d issues"
## edit /etc/pam.d/su to verify that only members of the wheel group have privileges enabling them to become 'root' by using the 'su' command and entering the 'root' password. 
cp -p /etc/pam.d/su /etc/pam.d/su.backup.$(date +%Y%m%d)
sed -i -e '/auth.*required.*pam_wheel.so.*use_uid/h; ${x;s/auth.*required.*pam_wheel.so.*use_uid//;{g;tF};a\' -e 'auth	required	pam_wheel.so	use_uid' -e '};:F;s/.*\(auth.*required.*pam_wheel.so.*use_uid\)/\1/;' /etc/pam.d/su
## RHEL 7 replaces cracklib.so with pwquality.so so this had no effect on RHEL 7.  These are managed in /etc/security/pwquality.conf
if [ $RHELVER -lt 7 ]
then
	## edit /etc/pam.d/system-auth to verify that passwords include at least a lowercase alphabetic character. Forcing users to use complex passwords makes it more difficult for attackers to gain access to the system.
	sed -i -e "/^password.*pam_cracklib.so.*lcredit.*/! s/\(^password.*pam_cracklib.so\) \(.*\)/\1 lcredit=-1 \2/g" /etc/pam.d/system-auth
	## edit /etc/pam.d/system-auth to verify that passwords include at least a numeric character. Forcing users to use complex passwords makes it more difficult for attackers to gain access to the system.
	sed -i -e "/^password.*pam_cracklib.so.*dcredit.*/! s/\(^password.*pam_cracklib.so\) \(.*\)/\1 dcredit=-1 \2/g" /etc/pam.d/system-auth
	## edit /etc/pam.d/system-auth to verify that passwords include at least an uppercase alphabetic character. Forcing users to use complex passwords makes it more difficult for attackers to gain access to the system.
	sed -i -e "/^password.*pam_cracklib.so.*ucredit.*/! s/\(^password.*pam_cracklib.so\) \(.*\)/\1 ucredit=-1 \2/g" /etc/pam.d/system-auth
else
	sed -i -e "s/.*\([dlu]credit\).*/\1 = 1/" /etc/security/pwquality.conf
fi

## Set permission and owner of /etc/cron.* paths and remove /etc/cron.deny
mv /etc/cron.deny /etc/cron.deny.backup.$(date +%Y%m%d)
chmod go-rwx /etc/cron.*
chown root:root /etc/cron.*

## set umask to 077 in /etc/bashrc and /etc/profile.d files
echo "fix umask issues in /etc/bashrc and /etc/profile.d files"
## This needs to be tested before implementing.  This may cause issues with log files and other items that require group and world read/write capabilities.
## The other option is to remove this from tripwire testing.
#for f in /etc/bashrc /etc/profile.d/*
#do
#	set -i -e '/umask.*/h; ${x;s/umask.*//;{g;tF};a\' -e 'umask 077' -e '};:F;s/umask.*/umask 077/' $f
#done

## set net.ipv4.conf settings
restart=0
echo "fix ICMP Redirects"
results=$(sysctl -n net.ipv4.conf.all.accept_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.all.accept_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi
results=$(sysctl -n net.ipv4.conf.default.accept_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.default.accept_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi

echo "fix net.ipv4 martians"
results=$(sysctl -n net.ipv4.conf.all.log_martians)
if [ $results -ne 1 ]
then
	echo net.ipv4.conf.all.log_martians=1 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi
results=$(sysctl -n net.ipv4.conf.default.log_martians)
if [ $results -ne 1 ]
then
	echo net.ipv4.conf.default.log_martians=1 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi

echo "fix net.ipv4 secure redirects"
results=$(sysctl -n net.ipv4.conf.all.secure_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.all.secure_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi
results=$(sysctl -n net.ipv4.conf.default.secure_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.default.secure_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi

echo "fix net.ipv4 send_redirects"
results=$(sysctl -n net.ipv4.conf.all.send_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.all.send_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi
results=$(sysctl -n net.ipv4.conf.default.send_redirects)
if [ $results -ne 0 ]
then
	echo net.ipv4.conf.default.send_redirects=0 >> /etc/sysctl.d/net.ipv4.conf
	restart=1
fi

# Remove unwanted programs
echo "Remove unwanted programs"
#telnet is a very useful client for testing.  It, in itself is NOT inherently dangerous.  We have nc, which is capable of doing the same thing, but much more difficult and more dangerous, and it isn't being removed.
#yum erase telnet


exit 0
