systemctl disable bluetooth.service  # Bluetooth, unnecessary on servers 
systemctl disable accounts-daemon.service  # GNOME accounts daemon, for desktop environments 
systemctl disable avahi-daemon.service  # mDNS discovery, potential info leak 
systemctl disable brltty.service  # Braille support, accessibility if not needed
systemctl disable debug-shell.service  # Debug shell, security risk
systemctl disable ModemManager.service  # Modem management, if no modems
systemctl disable pppd-dns.service  # PPP DNS, if not using PPP
systemctl disable cups.service  # Printing, if no printers 
#s
# Additional services recommended for disabling in Ubuntu 24.04 per CIS Benchmark
#
systemctl disable apport.service  # Crash reporting, data leakage risk
systemctl disable whoopsie.service  # Error reporting, outbound connections
systemctl disable isc-dhcp-server.service  # DHCP server, network exposure 
systemctl disable slapd.service  # LDAP server, auth vulnerabilities 
systemctl disable nfs-server.service  # NFS sharing, access risks 
systemctl disable named.service  # DNS server, potential attacks 
systemctl disable dnsmasq.service  # DNS caching/forwarding, if unused 
systemctl disable vsftpd.service  # FTP server, insecure protocol 
systemctl disable dovecot.service  # IMAP/POP server, email risks 
systemctl disable rpcbind.service  # RPC for NFS, legacy risks 
systemctl disable rsync.service  # File sync, remote transfer risks 
systemctl disable smbd.service  # Samba, Windows sharing vulnerabilities 
systemctl disable snmpd.service  # SNMP monitoring, info exposure 
systemctl disable tftpd.service  # TFTP server, insecure file transfer 
systemctl disable squid.service  # Web proxy, misuse potential 
systemctl disable apache2.service  # Apache web server, if not hosting 
systemctl disable nginx.service  # Nginx web server, similar risks 
systemctl disable xinetd.service  # Inetd super-server, legacy 
systemctl disable ypbind.service  # NIS client, insecure legacy 
systemctl disable ypserv.service  # NIS server, insecure 
systemctl disable postfix.service  # Mail agent, email relay risks
systemctl disable mysql.service  # MySQL database, data exposure
systemctl disable mariadb.service  # MariaDB alternative, if installed
systemctl disable atd.service  # At scheduler, if not used
systemctl disable autofs.service  # Auto-mounting, removable media risks 

