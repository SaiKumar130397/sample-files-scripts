# sample-files-scripts
Repo to maintain base files and bash scripts

A. bootstrap.sh

A. Check Cloud-Init Logs:

1. To check status (done/running/error): sudo cloud-init status
2. Main execution log: sudo cat /var/log/cloud-init-output.log
3. Detailed cloud-init log: sudo cat /var/log/cloud-init.log
4. To see the exact script that was executed: sudo cat /var/lib/cloud/instance/user-data.txt

B. View the Full Log - sudo cat /var/log/bootstrap.log

C. Watch Logs Live - sudo tail -f /var/log/bootstrap.log


