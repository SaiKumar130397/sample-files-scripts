# sample-files-scripts
Repo to maintain base files and bash scripts

1. bootstrap.sh

A. Check Cloud-Init Logs:
a. To check status (done/running/error)
 - sudo cloud-init status
b. Main execution log
 - sudo cat /var/log/cloud-init-output.log
c. Detailed cloud-init log
 - sudo cat /var/log/cloud-init.log
d. To see the exact script that was executed.
 - sudo cat /var/lib/cloud/instance/user-data.txt


B. View the Full Log - sudo cat /var/log/bootstrap.log

C. Watch Logs Live - sudo tail -f /var/log/bootstrap.log


