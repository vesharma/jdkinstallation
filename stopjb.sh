/root/jboss-eap-7.2.0.zip
/root/jboss-eap-7.2.5-patch.zip

 vi /ql/EAP-7.2.1/bin/stop-jb.sh

!#/bin/sh
kill -9 `ps -ef |grep -i java |grep -i 'Controller' |awk -F ' ' '{print $2}'`;
ps -ef |grep -i java |grep -i 'Controller' |awk -F ' ' '{print $2}';
 ps -ef |grep -i java |grep -i 'Controller';
ps -ef |grep -i java

chmod +x /ql/EAP-7.2.1/bin/stop-jb.sh
chown svc-lean.svc-leangrp /ql/EAP-7.2.1/bin/stop-jb.sh
ll /ql/EAP-7.2.1/bin/stop-jb.sh


chmod -R 775 /ql/EAP-7.2.1 ; chown -R svc-lean.svc-leangrp /ql/EAP-7.2.1
