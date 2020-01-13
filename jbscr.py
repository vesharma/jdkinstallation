#!/usr/bin/python
import os 
import sys 
from exceptions import EOFError, IOError
import paramiko
import subprocess
import shlex 
import time 
import logging  
import fileinput
import socket
import re 
import shutil
from tempfile import mkstemp  
import pdb
paramiko.util.log_to_file('/tmp/paramiko.log')

cmd="java "
arg="-jar /ql/jboss-eap-7.1.0-installer.jar"
domain=False 
host=False 
jgroup_name=None
chell="#!/bin/bash"

remotepath='/ql'
destpath='/ql'
logger = logging.getLogger("Process_Log")

infile="/ql/secrets.txt"

sysname=socket.gethostname()
syslist=sysname.split('.')
hostnm=syslist[0]
sysid=jgroup_name+"_"+hostnm
addr=socket.gethostbyname(socket.gethostname())
dc=hostnm+"-dc"
dcstr="\""+dc+"\""
hoststr="<host name=\""+hostnm+"-host"+"\""+" xmlns=\"urn:jboss:domain:5.0\">\n"
remoteorg="            <!-- <remote protocol=\"remote\" host=\"${jboss.domain.master.address}\" port=\"${jboss.domain.master.port:9999}\" security-realm=\"ManagementRealm\"/> -->\n"
if host==True:
   remotestr="          <remote protocol=\"remote\" host=\"${jboss.domain.master.address:"+domaincip+"}\""+" port=\"${jboss.domain.master.port:9999}\" security-realm=\"ManagementRealm\" username=\""+jbossadmin+"\"/>\n"

groupstr="         <server-group name=\""+jgroup_name+"\" profile=\"full-ha\">\n"
jvmstr="           <server name=\"server-three\" group=\"other-server-group\" auto-start=\"false\">\n"
jvmstr2="          <server name="+"\""+sysid+"\""+" group=\""+jgroup_name+"\""+" auto-start=\"true\">\n"
sockstr="          <socket-bindings socket-binding-group=\"full-ha-sockets\" port-offset=\"0\"/>\n"

if domain==True:
   logger.info('Processing configuration files...') 
   ftmp=open('sedmod.txt', 'a')
   ftmp.write("<host xmlns=\"urn:jboss:domain:5.0\" name="+dcstr+">\n")
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<host xmlns=\"urn:jboss:domain:5.0\" name=\"master\">/ {\' -e \'r sedmod.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml")
   ftmp=open('sedmod1.txt', 'a')
   inetstr1="          <inet-address value=\"${jboss.bind.address.management:"+addr+"}\"/>\n"
   ftmp.write(inetstr1)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<inet-address value=\"${jboss.bind.address.management:127.0.0.1}\"\/>/{\' -e \'r sedmod1.txt\' -e \'d\' -e \'}\'  -i /ql/EAP-7.1.1/domain/configuration/host.xml")
   inetstr2="           <inet-address value=\"${jboss.bind.address:"+addr+"}\"/>\n"
   ftmp = open('sedmod2.txt', 'a')
   ftmp.write(inetstr2)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<inet-address value=\"${jboss.bind.address:127.0.0.1}\"\/>/{\' -e \'r sedmod2.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml") 
   ftmp=open('dommod.txt', 'a')
   ftmp.write(groupstr)
   ftmp.close()
   os.system(" sed  -i \'/<servers>/, /<\\/servers>/ d\' /ql/EAP-7.1.1/domain/configuration/host.xml")
   time.sleep(1) 
   os.system("sed -e \'/<server-group name=\"main-server-group\" profile=\"full\">/{\' -e  \'r dommod.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/domain.xml") 
   os.system("rm -f sed*.txt")
   os.system("rm -f dom*.txt") 
   os.system("rm -f *.out*")
   print 'Please save the \'secret\' from the add-users script in a \'secrets.txt\' file on each jboss node in the ql directory\n'
   input=raw_input('-Hit CR to continue')

else:
   logger.info('Processing configuration files...')
   ftmp=open('sedmod.txt','a')
   ftmp.write("<?xml version=\"1.0\" encoding=\'UTF-8\' ?>\n")
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<?xml version=\"1.0\" ?>/{\' -e \'r sedmod.txt\' -e \'d\' -e \'}\' -i  /ql/EAP-7.1.1/domain/configuration/host.xml") 
   inetstr1="           <inet-address value=\"${jboss.bind.address.management:"+addr+"}\"/>\n"
   inetstr2="           <inet-address value=\"${jboss.bind.address:"+addr+"}\"/>\n"
   ftmp=open('sedmod1.txt', 'a') 
   ftmp.write(hoststr)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<host xmlns=\"urn:jboss:domain:5.0\" name=\"master\">/{\' -e \'r sedmod1.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml  ")
   ftmp=open('seccode1.txt', 'a')
   ftmp.write("                     <server-identities>\n")
   ftmp.close()
   ftmp=open('seccode2.txt','a')
   ftmp.write("                     </server-identities>\n") 
   ftmp.close()
   time.sleep(1)
   os.system("sed \'/<security-realm name=\"ManagementRealm\">/r seccode1.txt\' -i /ql/EAP-7.1.1/domain/configuration/host.xml ") 
   os.system("sed -i \'/<server-identities>/r  seccode2.txt\' /ql/EAP-7.1.1/domain/configuration/host.xml ")
   ftmp=open('/ql/secrets.txt','r')
   seccode=ftmp.readline()
   ftmp.close()
   seccode="                            "+seccode+"\n"
   ftmp=open('modsecret.txt','a')
   ftmp.write(seccode)
   ftmp.close()
   time.sleep(1)
   os.system("sed -i \'/<server-identities>/r modsecret.txt\' /ql/EAP-7.1.1/domain/configuration/host.xml")  
   ftmp=open('sedmod2.txt', 'a') 
   ftmp.write("        <!--<local/>-->\n")
   ftmp.close()
   time.sleep(1)
   os.system("sed -e  \'/<local\/>/{\' -e  \'r sedmod2.txt\' -e \'d\' -e \'}\'  -i /ql/EAP-7.1.1/domain/configuration/host.xml")
   ftmp=open('sedmod3.txt', 'a') 
   ftmp.write(remotestr)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e  \'/<!-- <remote protocol=\"remote\" host=\"${jboss.domain.master.address}\" port=\"${jboss.domain.master.port:9999}\" security-realm=\"ManagementRealm\"\/> -->/{\' -e \'r sedmod3.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml")
   ftmp=open('sedmod4.txt','a') 
   ftmp.write(inetstr1)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e \'/<inet-address value=\"${jboss.bind.address.management:127.0.0.1}\"\/>/{\' -e \'r sedmod4.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml ")  
   ftmp=open('sedmod5.txt','a')
   ftmp.write(inetstr2)
   ftmp.close()
   time.sleep(1)
   os.system("sed -e  \'/<inet-address value=\"${jboss.bind.address:127.0.0.1}\"\/>/{\' -e \'r sedmod5.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml ")
   ftmp =open('sedmod6.txt','a') 
   ftmp.write(jvmstr2)
   ftmp.close()  
   time.sleep(1)
   os.system("sed -e \'/<server name=\"server-three\" group=\"other-server-group\" auto-start=\"false\">/{\' -e \'r sedmod6.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml")
   ftmp=open('sedmod7.txt', 'a')
   ftmp.write(sockstr)
   ftmp.close() 
   time.sleep(1)
   os.system("sed -e \'/<socket-bindings port-offset=\"250\"\/>/{\' -e \'r sedmod7.txt\' -e \'d\' -e \'}\' -i /ql/EAP-7.1.1/domain/configuration/host.xml")  
   os.system(" sed \'/<server name=\"server-two\" group=\"main-server-group\" auto-start=\"true\">/, /<\\/server>/ d\' /ql/EAP-7.1.1/domain/configuration/host.xml  > host.1")
   os.system("  sed \'/<server name=\"server-one\" group=\"main-server-group\">/, /<\\/server>/ d\' host.1 > /ql/EAP-7.1.1/domain/configuration/host.xml")
   os.system("sed -i \'26{/<\/server-identities>/s/^/<!-- /;/<\/server-identities>/s/$/ -->/}\' /ql/EAP-7.1.1/domain/configuration/host.xml")
   os.system("rm -f *.out*")
   os.system("rm -f sed*.txt")
   os.system("rm -f sec*.txt")
   os.system("rm -f *.1")
   os.system("rm -f modsecret.txt")

logger.info('Configuring Start-up scripts...')
os.system("cp /ql/EAP-7.1.1/bin/init.d/*.sh /etc/init.d")
os.system("cp /ql/EAP-7.1.1/bin/init.d/*.conf /etc/default")
os.system("ln -sf /etc/init.d/jboss-eap-rhel.sh /etc/rc3.d/S80jboss-eap-rhel.sh")
os.system("ln -sf /etc/init.d/jboss-eap-rhel.sh /etc/rc5.d/S80jboss-eap-rhel.sh")
os.system("ln -sf /etc/init.d/jboss-eap-rhel.sh /etc/rc6.d/K20jboss-eap-rhel.sh")
if domain==True:
   domstr="./domain.sh -bmanagement "+addr+" -b "+addr
   ftmp=open('/ql/EAP-7.1.1/bin/start-jb.sh','a')
   ftmp.write(chell)
   ftmp.write("\n\n\n")
   ftmp.write(domstr)
   ftmp.close()
else:
   nodestr="./domain.sh -bmanagement "+addr+" -b "+addr+"  -Djboss.domain.master.address="+domaincip
   ftmp=open('/ql/EAP-7.1.1/bin/start-jb.sh','a')
   ftmp.write(chell)
   ftmp.write("\n\n\n")
   ftmp.write(nodestr)
   ftmp.close()

os.system("find /ql/EAP-7.1.1 -type d -exec chmod 2775 {} \;")
os.system("find /ql/EAP-7.1.1 -type f -exec chmod 2775 {} \;")
os.system("chown -R svc-lean:svc-leangrp /ql/EAP-7.1.1/")

os.system("sed -i \'s/# JAVA_HOME=\"\/usr\/lib\/jvm\/default-java\"/JAVA_HOME=\"\/ql\/java\/java-current\"/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_HOME=\"\/opt\/jboss-eap\"/JBOSS_HOME=\"\/ql\/EAP-7.1.1\"/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_USER=jboss-eap/JBOSS_USER=pcsos/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_MODE=standalone/JBOSS_MODE=domain/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_DOMAIN_CONFIG=domain.xml/JBOSS_DOMAIN_CONFIG=domain.xml/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_HOST_CONFIG=host-master.xml/JBOSS_HOST_CONFIG=host.xml/\' /etc/default/jboss-eap.conf")
os.system("sed -i \'s/# JBOSS_CONSOLE_LOG=\"\/var\/log\/jboss-eap\/console.log\"/JBOSS_CONSOLE_LOG=\"\/var\/log\/jboss-eap\/console.log\"/\' /etc/default/jboss-eap.conf")

logger.info('Jboss setup is complete!') 
a
dfadf
