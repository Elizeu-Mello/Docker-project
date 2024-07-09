# Atividade - AWS - Docker
---
## Sobre a Atividade

### Descrição
1. Instalação e configuração do Docker ou containerd no host EC2.
2. Efetuar o deploy de uma aplicação WordPress com um container de aplicação e um banco de dados MySQL RDS.
3. Configuração da utilização do serviço EFS AWS para arquivos estáticos do container de aplicação WordPress.
4. Configuração do serviço de Load Balancer AWS para a aplicação WordPress.

**Pontos de atenção:**
- Não utilizar IP público para saída do serviço WordPress (evitar publicar o serviço WP via IP público).
- Sugestão para o tráfego de internet sair pelo Load Balancer (Load Balancer Classic).
- Pastas públicas e arquivos estáticos do WordPress devem utilizar o EFS (Elastic File System).
- A aplicação WordPress precisa estar rodando na porta 80 ou 8080.

### Portas utilizadas para o Security Group
- HTTP: TCP 80
- HTTPS: TCP 443
- SSH: TCP 22
- MySQL/Aurora: TCP 3306
- NFS: TCP 2049

### Configurações da VPC
1. Criar VPC
2. Configurações da VPC:
   - Número de zonas de disponibilidade: 2
   - Número de sub-redes públicas: 2
   - Número de sub-redes privadas: 2
   - Gateways NAT: 1 (em uma AZ)
   - Endpoints da VPC: Nenhum

### Criação e configurações do RDS
1. Vá para o console da AWS e procure pelo serviço Amazon RDS.
2. Criar banco de dados.
3. Criação padrão:
   - Tipo de mecanismo: MySQL
   - Versão do mecanismo: 8.0.35
   - Modelos: Nível gratuito
   - Configure as opções de credenciais como nome do banco de dados, nome do usuário e senha.
4. Configuração da instância do RDS:
   - Tipo de instância: db.t3.micro
   - Armazenamento: gp2 20 GB
5. Conectividade:
   - Não se conectar a um recurso de computação do EC2.
   - Escolher a VPC criada para o projeto.
   - Grupo de sub-redes de banco de dados: default-vpc.
   - Acesso público: Não.
   - Zona de disponibilidade: Sem preferência.

### Criação do EFS
1. Criar sistema de arquivos:
   - Personalizado
   - Nome: Defina um nome para seu EFS
   - Tipo do sistema de arquivos: Regional
2. Redes:
   - VPC: Selecionar a criada no começo
   - Destinos de montagem: Selecionar as zonas de disponibilidade e adicionar o grupo de segurança EFS
   - Deixar tudo no padrão e criar

### Criação e configuração do EC2
1. Criar uma instância EC2:
   - Tipo de instância: t3.small
   - AMI: Amazon Linux 2
   - Armazenamento: 8 GB gp2
   - Criar um par de chaves
   - Configurações de rede: Usar a VPC e sub-rede privada_1a
   - Selecionar grupo de segurança criado no começo
   - Detalhes avançados: Cole o script sh
```
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
```
      
   - Execute a instância
   - Não se esqueça de configurar um endpoint EC2 Connect Instance para se conectar ao terminal da instância

1. Criar um Modelo de execução:
   - Dar um nome ao modelo
   - Repetir toda a configuração feita na criação da EC2 acima
2. Em EC2, executar instância a partir do modelo:
   - Modificar somente as subnets para privada_2b

### Criação do Grupo de Destino
1. Configuração básica:
   - Tipo de destino: Instâncias
   - Protocolo: HTTPS:80
   - Tipo de endereço IP: IPv4
   - Versão do protocolo: HTTP1
2. Registrar destinos:
   - Selecionar as duas instâncias e incluir como pendente abaixo
   - Criar grupo de destino

### Criação do Load Balancer
1. Utilizar o Application Load Balancer:
   - Voltado para a Internet
   - Tipo de endereço IP do balanceador de carga: IPv4
   - Mapeamento de rede: Selecionar a VPC da atividade e mapear as duas zonas de disponibilidade
2. Listeners e roteamento:
   - HTTP: 80 | Ação padrão para o grupo de destino criado acima

### Configuração do Auto Scaling
1. Selecionar o modelo de execução criado anteriormente:
   - Rede:
     - Selecionar a VPC usada no projeto
     - Definir as zonas de disponibilidade e sub-redes que o Auto Scaling irá atuar
2. Configurar opções avançadas:
   - Anexar a um balanceador de carga existente
   - Selecionar o grupo de destino criado anteriormente
   - Ativar as verificações de integridade do Elastic Load Balancing
3. Configurações adicionais:
   - Habilitar coleta de métricas de grupo no CloudWatch
4. Escalabilidade:
   - Capacidade mínima desejada: 1
   - Capacidade máxima desejada: 2
5. Política de manutenção de instâncias:
   - Escolher um comportamento de substituição dependendo dos seus requisitos de disponibilidade
