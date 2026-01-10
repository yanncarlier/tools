
#!/usr/bin/env bash
#+ disable_services_ubuntu24.sh
#+ Summary: Disable a set of common services on Ubuntu 24.04 that are often
#+ unnecessary on servers or increase attack surface. Review before running.
#+ WARNING: Disabling services can break expected functionality. Test on a
#+ non-production host first.

set -euo pipefail

# Core services often disabled on minimal server installs
systemctl disable bluetooth.service
systemctl disable accounts-daemon.service
systemctl disable avahi-daemon.service
systemctl disable brltty.service
systemctl disable debug-shell.service
systemctl disable ModemManager.service
systemctl disable pppd-dns.service
systemctl disable cups.service

# Additional candidates (review before disabling on any host)
systemctl disable apport.service
systemctl disable whoopsie.service
systemctl disable isc-dhcp-server.service
systemctl disable slapd.service
systemctl disable nfs-server.service
systemctl disable named.service
systemctl disable dnsmasq.service
systemctl disable vsftpd.service
systemctl disable dovecot.service
systemctl disable rpcbind.service
systemctl disable rsync.service
systemctl disable smbd.service
systemctl disable snmpd.service
systemctl disable tftpd.service
systemctl disable squid.service
systemctl disable apache2.service
systemctl disable nginx.service
systemctl disable xinetd.service
systemctl disable ypbind.service
systemctl disable ypserv.service
systemctl disable postfix.service
systemctl disable mysql.service
systemctl disable mariadb.service
systemctl disable atd.service
systemctl disable autofs.service

