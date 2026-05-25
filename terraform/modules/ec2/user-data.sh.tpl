#!/bin/bash
set -euxo pipefail

exec > /var/log/user-data.log 2>&1

sudo labauto ansible

rm -rf /opt/roboshop-ansible
git clone "${ansible_repo_url}" /opt/roboshop-ansible
cd /opt/roboshop-ansible/ansible

cat > group_vars/all.yml <<EOF
---
env: "${env}"
EOF

export PATH=/usr/local/bin:/usr/sbin:/usr/bin:$PATH
ansible-playbook -i localhost, -c local main.yml -e "COMPONENT=${component}"
