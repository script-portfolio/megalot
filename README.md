
### Organize sms-feed on sertain event on some site. Minimize the access to this site.





### Installation:

    ln -s $(pwd)/get_last0.sh  /usr/local/bin/

Server Side installation
    ln -s $(pwd)/get_last0.sh  /usr/local/bin/
    ln -s $(pwd)/mega-loop.sh /usr/local/bin/
    ln -s $(pwd)/mega-status.sh /usr/local/bin/

    ln -s $(pwd)/etc/megalot.crontab  /etc/cron.d

Check (crontab):
    find /etc/cron.d/ -ls -follow | grep megalot

DO NOT FORGET ABOUT time-text
DO NOT FORGET ABOUT pbsms

