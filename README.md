# sample-files-scripts
Repo to maintain base files and bash scripts

A. bootstrap.sh

1. Check Cloud-Init Logs:

- To check status (done/running/error): sudo cloud-init status
- Main execution log: sudo cat /var/log/cloud-init-output.log
- Detailed cloud-init log: sudo cat /var/log/cloud-init.log
- To see the exact script that was executed: sudo cat /var/lib/cloud/instance/user-data.txt

2. View the Full Log - sudo cat /var/log/bootstrap.log

3. Watch Logs Live - sudo tail -f /var/log/bootstrap.log

4. Jenkins admin password - sudo cat /var/lib/jenkins/.jenkins/secrets/initialAdminPassword

