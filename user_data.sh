#!/bin/bash

sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
sudo yum install amazon-efs-utils -y
sudo mkdir /mnt/efs/
sudo chmod +rwx /mnt/efs/

#DNS do console do EFS para a montagem
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-05c14ff1b3393f8cc.efs.us-east-1.amazonaws.com:/ /mnt/efs

# Adiciona a entrada no fstab para montar o EFS automaticamente
echo "fs-05c14ff1b3393f8cc.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab

# Cria o arquivo de configuração do Docker Compose
cat <<EOF > /mnt/efs/docker-compose.yml
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    volumes:
      - /mnt/efs/wordpress:/var/www/html
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: wordpressdb.chgeksy88imk.us-east-1.rds.amazonaws.com
      WORDPRESS_DB_NAME: wordpressDB
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: ****
      WORDPRESS_TABLE_PREFIX: wp_
EOF

cd /mnt/efs
sudo docker-compose up -d
