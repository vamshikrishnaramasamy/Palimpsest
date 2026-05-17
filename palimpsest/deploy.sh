#!/bin/bash
set -e
npm run build
rsync -avz --delete -e "ssh -i ~/.ssh/palimpsest_vps" build/ ubuntu@64.181.233.156:~/palimpsest/build/
ssh -i ~/.ssh/palimpsest_vps ubuntu@64.181.233.156 "sudo systemctl restart palimpsest"
echo "Deployed!"
