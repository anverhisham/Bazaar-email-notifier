-DESCRIPTION

	This perl script act as an hookless email notifier for Bazaar repository. This script is easy to install and maintain in a server. Do following steps in Bazaar repository server, to install the script.



-INSTALLATION STEPS

1. Add source-email address ($sourceEmailAddress) to line:22 of file 'sendEmailUponCommit.pl'. Add all recipient email-addresses (one per line) to file 'mailListToSendCommit.txt'

2. Move both script file & mailList file to the bazaar repository folder. Let's say '/Repository/trunk' is the repository,
	mv sendEmailUponCommit.pl /Repository/trunk/
	mv mailListToSendCommit.txt /Repository/trunk/

3. Open file '/etc/crontab' using sudo, and add the below lines. This is to ensure that every 10min, script is executed and log is printed to file 'sendEmailUponCommit.log'.

01,11,21,31,41,51 *     * * *   root    /Repository/trunk/sendEmailUponCommit.pl >> /Repository/trunk/sendEmailUponCommit.log


-REQUIREMENT
	LINUX/UNIX machine with Perl 5 (or above) and mail utility installed.

