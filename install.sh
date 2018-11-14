#!/bin/bash 
# Este script é baseado nos videos da série monitoração do canal linuxtips no youtube feitos pelo Jefferson Fernando
# E tem como objetivo fazer tudo que foi apresentado nos videos ser feito de forma automatizada via Shell Script 
# Link do Canal https://www.youtube.com/user/linuxtipscanal/videos 

###############  Netdata ###############
# Nome do video: [ Série Monitoração ] - 02 - O Sensacional NETDATA
# Link do video no qual foram baseados os comandos para a instalação e configuração do Netdata
# https://www.youtube.com/watch?v=H-ZxEnYjLfM

############### Prometheus ###############
# Nome do video: [ Série Monitoração ] - 03 -  Instalando e configurando o PROMETHEUS no Ubuntu e CentOS!
# Link do video no qual foram baseados os comandos para a instalação e configuração do Prometeus
# https://www.youtube.com/watch?v=OnzIUGHl9no

###############  Node Exporter  ###############
# Nome do video: [ Série Monitoração ] - 04 - Instalando o Node Exporter e Integrando o Prometheus com o Netdata 
# Link do video no qual foram baseados os comandos para a instalação e configuração do Node Exporter
# https://www.youtube.com/watch?v=uN6BtGXnnzs

###############  Alert Manager  ###############
# Nome do video: [ Série Monitoração ] - 05 - Integrando o AlertManager com o Prometheus, Slack ou RocketChat   
# Link do video no qual foram baseados os comandos para a instalação e configuração do Alert Manager
# https://www.youtube.com/watch?v=BWPOLLC1TE8

###############  Grafana  ###############
# Nome do video: [ Série Monitoração ] - 07 - Instalando e integrando o GRAFANA!
# Link do video no qual foram baseados os comandos para a instalação e configuração do Grafana
# https://www.youtube.com/watch?v=3K_FkcMwzAk

ip=`hostname -I | cut -d' ' -f1` # Pega o ip da máquina para configura-lá como um servidor Netdata 
dominio=$ip
prometheusrepo=prometheus/prometheus # Repositorio github
nodeexporterrepo=prometheus/node_exporter # Repositorio github
alertmanagerrepo=prometheus/alertmanager # Repositorio github

###############  Netdata ###############
#Instalando pré-requisitos
apt-get update >> /dev/null && apt-get install -yqq curl wget net-tools git jq dirmngr build-essential apt-transport-https

#Download e instalação do Netdata
#curl -fsSL https://my-netdata.io/kickstart.sh | bash  
bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait --dont-start-it

#Habilitando Netdata para autostart 
systemctl enable netdata

#Reiniciando o Netdata para poder aplicar as alterações feitas no netdata.conf
systemctl restart netdata

### No cliente 
# Descomentar a linha registry to announce e muda para url do servidor  

### No servidor
# Descomentar a linha enabled e muda para yes 
# Descomentar a linha registry to announce e muda para url do servidor  
systemctl status netdata | cat && sleep 5 && netstat -atunp | grep 19999 && sleep 5 #|| echo "Erro netdata não esta em execução" && exit
wget -O /etc/netdata/netdata.conf "http://localhost:19999/netdata.conf"
sed -i "/registry\s*to\s*announce /a  \#Linha adicionada para habilitar o servidor \n \tregistry to announce = http://$ip:19999 \n\#Linha adicionada para habilitar o registro no servidor \n \tenabled = yes" /etc/netdata/netdata.conf
#sed -i "/registry\s*to\s*announce /a  \#Linha adicionada para habilitar o servidor \n \tregistry\ to\ announce\ \=\ http\:\/\/$ip:19999 \n\#Linha adicionada para habilitar o registro no servidor \n \tenabled = yes" /etc/netdata/netdata.conf
#sed -i "/registry\s*to\s*announce /a  \#Linha adicionada para habilitar o servidor \n \tregistry\ to\ announce\ \=\ https\:\/\/$ip \n\#Linha adicionada para habilitar o registro no servidor \n \tenabled = yes" /etc/netdata/netdata.conf
systemctl restart netdata

############### Prometheus ###############

#Criando os diretórios necessários
mkdir /etc/prometheus
mkdir /var/lib/prometheus

#Criando os usuários 
useradd --no-create-home --shell /bin/false prometheus
useradd --no-create-home --shell /bin/false node_exporter

#Baixando o Prometheus
#curl -LO https://github.com/prometheus/prometheus/releases/download/v2.4.3/prometheus-2.4.3.linux-amd64.tar.gz
curl -sLO `curl -s https://api.github.com/repos/$prometheusrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64`
prometheusarq=`curl -s https://api.github.com/repos/$prometheusrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64 | cut -d\/ -f9`

#Extraindo o Prometheus
#tar xvf $prometheusarq
dirprometheus=`tar xvf $prometheusarq | cut -d/ -f1 | head -n 1`

#Copiando os arquivos necessários para os diretórios
cp $dirprometheus/prometheus /usr/local/bin/
cp $dirprometheus/promtool /usr/local/bin/ 
cp -r $dirprometheus/consoles /etc/prometheus/ 
cp -r $dirprometheus/console_libraries /etc/prometheus/ 

#Apagando arquivos baixados 
rm -rf prometheus*

# Arquivo prometheus.yml disponivel em 
# https://pastebin.com/QKctdHkh 

# Cria o arquivo prometheus.yml em /etc/prometheus/ com o conteúdo abaixo
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval:     10s
  evaluation_interval: 20s
rule_files:
  - 'alert.rules'
scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
         - targets: ['localhost:9090']
EOF

# Arquivo alert.rules disponivel em 
# https://pastebin.com/zkeyTf1t 

# Cria o arquivo alert.rules em /etc/prometheus/ com o conteúdo abaixo
cat > /etc/prometheus/alert.rules << EOF
groups:
- name: example
  rules:

  # Alert for any instance that is unreachable for >5 minutes.
  - alert: service_down
    expr: up == 0
    for: 2m
    labels:
      severity: page
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes."
  
  - alert: high_load
    expr: node_load1 > 0.5
    for: 2m
    labels:
      severity: page
    annotations:
      summary: "Instance {{ $labels.instance }} under high load"
      description: "{{ $labels.instance }} of job {{ $labels.job }} is under high load."
EOF

# Alterando o dono dos arquivos
chown prometheus:prometheus /usr/local/bin/prometheus 
chown prometheus:prometheus /usr/local/bin/promtool 
chown -R prometheus:prometheus /etc/prometheus 
chown -R prometheus:prometheus /var/lib/prometheus 

# Arquivo prometheus.service baseado no disponivel em 
# https://pastebin.com/DiqZYbNb 

# Cria o arquivo do serviço prometheus.service em /etc/systemd/system/ com o conteúdo abaixo
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

#Recarregar o daemon do systemd para disponibilizar o novo serviço adicionado 
systemctl daemon-reload

#Habilitando Prometheus para autostart 
systemctl enable prometheus 

#Iniciando o Prometheus 
systemctl start prometheus 

#Verificando se está tudo certo caso contrário exibe uma tela de erro e sai do script  
systemctl status prometheus | cat && sleep 5 && netstat -atunp | grep 9090 && sleep 5 #|| echo "Erro Prometheus não esta em execução" && exit

###############  Node Exporter  ###############
#Baixando o Node Exporter
#curl -LO https://github.com/prometheus/node_exporter/releases/download/v0.16.0/node_exporter-0.16.0.linux-amd64.tar.gz
curl -sLO `curl -s https://api.github.com/repos/$nodeexporterrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64`
nodeexporterarq=`curl -s https://api.github.com/repos/$nodeexporterrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64 | cut -d\/ -f9`

#Extraindo o Node Exporter
dirnodexporter=`tar xvf $nodeexporterarq | cut -d/ -f1 | head -n 1`

#Copiando o Node Exporter
cp $dirnodexporter/node_exporter /usr/local/bin

#Criando o usuário do Node Exporter
useradd node_exporter

#Alterando o dono dos arquivos
chown node_exporter:node_exporter /usr/local/bin/node_exporter 

#Apagando arquivos baixados 
rm -rf node_exporter*

#Arquivo node_exporter.service disponivel em 
#https://pastebin.com/7aCCPsjU

# Criando o arquivo do serviço node_exporter.service em /etc/systemd/system/ com o conteúdo abaixo
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

#Recarregar o daemon do systemd para disponibilizar o novo serviço adicionado 
systemctl daemon-reload

#Habilitando Node Exporter para autostart 
systemctl enable node_exporter

#Iniciando o Node Exporter 
systemctl start node_exporter

#Verificando se está tudo certo caso contrário exibe uma tela de erro e sai do script  
systemctl status node_exporter | cat && sleep 5 && netstat -atunp | grep 9100 && sleep 5 #|| echo "Erro Node Exporter não esta em execução" && exit

# Integrando o Prometheus + Netdata

#Arquivo prometheus.service disponivel em 
#https://pastebin.com/sAvbuySw

#Fazendo um backup do arquivo antigo
cp /etc/systemd/system/prometheus.service /etc/systemd/system/prometheus.service.bkp

# Criando o arquivo novo do serviço prometheus.service em /etc/systemd/system/ com o conteúdo abaixo
#cat > /etc/systemd/system/prometheus.service << EOF
cat > /etc/prometheus/prometheus.yml << EOF
global:
        scrape_interval:     10s
        evaluation_interval: 10s
        external_labels:
                monitor: 'teste-monitoring'
                rule_files:
                        - 'alert.rules'
                alerting:
                        alertmanagers:
                                - scheme: http
                                  static_configs:
                                          - targets:
                                                  - "localhost:9093"

                                            scrape_configs:
                                                    - job_name: 'node'
                                                      scrape_interval: 5s
                                                      static_configs:
                                                              #- targets: ['localhost:9090','localhost:8080','localhost:9100']
                                                              - targets: ['localhost:9090','localhost:8080','localhost:9100']
                                                              - job_name: 'netdata'
                                                                metrics_path: '/api/v1/allmetrics'
                                                                params:
                                                                        format: [prometheus]
                                                                        honor_labels: true
                                                                        scrape_interval: 5s
                                                                        static_configs:
                                                                                - targets: ['localhost:19999']
EOF

#Recarregar o daemon do systemd para disponibilizar o novo serviço adicionado 
systemctl daemon-reload

#Reiniciando o Prometheus 
systemctl restart prometheus 

#Verificando se está tudo certo caso contrário exibe uma tela de erro e sai do script  
systemctl status prometheus | cat && sleep 5 && netstat -atunp | grep 9090 && sleep 5 #|| echo "Erro Prometheus não esta em execução" && exit

###############  Alert Manager  ###############
# [ Série Monitoração ] - 05 - Integrando o AlertManager com o Prometheus, Slack ou RocketChat   
#Link video no qual foram baseados os comandos abaixo https://www.youtube.com/watch?v=BWPOLLC1TE8

#Baixando o Alert Manager
curl -sLO `curl -s https://api.github.com/repos/$alertmanagerrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64`
alertmanagerarq=`curl -s https://api.github.com/repos/$alertmanagerrepo/releases/latest | jq -r ".assets[] | .browser_download_url" | grep -i linux| grep -i amd64 | cut -d\/ -f9`

#Extraindo o Alert Manager 
diralertmanager=`tar xvf $alertmanagerarq | cut -d/ -f1 | head -n 1`

#Copiando o binário para o diretório
cp $diralertmanager/alertmanager /usr/local/bin/

# Alterando o dono do binário
chown prometheus:prometheus /usr/local/bin/alertmanager

#Criando os diretórios necessários
mkdir /etc/alertmanager
mkdir -p /var/lib/alertmanager/data

#Arquivo config.yml para Slack
#https://pastebin.com/R6xegjLn
#route:
#     receiver: 'slack'
#
#receivers:
#     - name: 'slack'
#        slack_configs:
#             - send_resolved: true
#                username: 'YOUR USERNAME'
#                channel: '#YOURCHANNEL'
#                api_url: 'INCOMMING WEBHOOK'
#Como gerar o Incoming Webhook no Slack:
#https://api.slack.com/incoming-webhooks

#Arquivo config.yml para RocketChat
# https://pastebin.com/ffWWSeQd

# Cria o arquivo do serviço config.yml em /etc/alertmanager/
cat > /etc/alertmanager/config.yml << EOF
route:
    repeat_interval: 30m
    group_interval: 30m
    receiver: 'rocketchat'

receivers:
    - name: 'rocketchat'
      webhook_configs:
          - send_resolved: false
            url: 'INCOMING_WEBHOOK'
EOF

# Alterando o dono do arquivo configuração
chown prometheus:prometheus /etc/alertmanager/ -R 
chown prometheus:prometheus /var/lib/alertmanager/data/ -R 

# Arquivo alertmanager.service baseado no disponivel em 
# https://pastebin.com/8gijAtNf

# Cria o arquivo do serviço alertmanager.service em /etc/systemd/system/ com o conteúdo abaixo
cat > /etc/systemd/system/alertmanager.service << EOF
[Unit]
Description=alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/config.yml --storage.path /var/lib/alertmanager/data

[Install]
WantedBy=multi-user.target
EOF

#Recarregar o daemon do systemd para disponibilizar o novo serviço adicionado 
systemctl daemon-reload

#Habilitando Alert Manager para autostart 
systemctl enable alertmanager 

#Iniciando o Prometheus 
systemctl start alertmanager

#Verificando se está tudo certo caso contrário exibe uma tela de erro e sai do script  
systemctl status alertmanager | cat && sleep 5 && netstat -atunp | grep 9090 && sleep 5 #|| echo "Erro Prometheus não esta em execução" && exit


cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval:     10s
  evaluation_interval: 10s
  external_labels:
      monitor: 'teste-monitoring'
rule_files:
  - 'alert.rules'
alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets:
      - "localhost:9093"

scrape_configs:
  - job_name: 'node'
    scrape_interval: 5s
    static_configs:
#         - targets: ['localhost:9090','localhost:8080','localhost:9100']
         - targets: ['localhost:9090','localhost:9100']

  - job_name: 'netdata'
    metrics_path: '/api/v1/allmetrics'
    params:
      format: [prometheus]
    honor_labels: true
    scrape_interval: 5s
    static_configs:
         - targets: ['localhost:19999']
EOF

#Reiniciando o Prometheus 
systemctl restart prometheus 

#Instalaçao do RocketChat no Debian 
#https://rocket.chat/docs/installation/manual-installation/debian/
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/3.6 main" | tee /etc/apt/sources.list.d/mongodb-org-3.6.list
curl -sL https://deb.nodesource.com/setup_8.x | bash -
apt-get update && apt-get install -y mongodb-org nodejs graphicsmagick && `which npm` install -g inherits n && n 8.11.3

cat > /etc/mongod.conf << EOF
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
#  engine:
#  mmapv1:
#  wiredTiger:

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  #bindIp: 127.0.0.1
  bindIp: 0.0.0.0


# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

#security:

#operationProfiling:

#replication:

#sharding:

## Enterprise-Only Options:

#auditLog:

#snmp:
EOF

curl -L https://releases.rocket.chat/latest/download -o /tmp/rocket.chat.tgz
tar -xzf /tmp/rocket.chat.tgz -C /tmp
cd /tmp/bundle/programs/server && npm install
mv /tmp/bundle /opt/Rocket.Chat
useradd -M rocketchat && usermod -L rocketchat
chown -R rocketchat:rocketchat /opt/Rocket.Chat
echo -e "[Unit]\nDescription=The Rocket.Chat server\nAfter=network.target remote-fs.target nss-lookup.target nginx.target mongod.target\n[Service]\nExecStart=/usr/local/bin/node /opt/Rocket.Chat/main.js\nStandardOutput=syslog\nStandardError=syslog\nSyslogIdentifier=rocketchat\nUser=rocketchat\nEnvironment=MONGO_URL=mongodb://localhost:27017/rocketchat ROOT_URL=http://$dominio:3300/ PORT=3300\n[Install]\nWantedBy=multi-user.target" | tee /lib/systemd/system/rocketchat.service
systemctl enable mongod && systemctl start mongod
systemctl status mongod | cat && sleep 5 && netstat -atunp | grep 27017 && sleep 5 #|| echo "Erro mongodb não esta em execução" && exit
systemctl enable rocketchat && systemctl start rocketchat
systemctl status rocketchat | cat && sleep 5 && netstat -atunp | grep 3300 && sleep 5 #|| echo "Erro rocketchat não esta em execução" && exit

#Script de incoming webhook
# https://github.com/badtuxx/giropops-monitoring/blob/master/conf/rocketchat/incoming-webhook.js
#Copiar a URL gerada 
# http://ip:3300/hooks/rvd2NpNFgyo4NhCec/j392TB4QC2bGrAzDL5bv3NsS2QwRrqoCxkAiWevpmq4z73zf

#Grafana
echo  "deb https://packagecloud.io/grafana/stable/debian/ stretch main" > /etc/apt/sources.list.d/grafana.list
curl https://packagecloud.io/gpg.key | apt-key add -
apt-get update && apt-get install -y grafana
systemctl restart grafana-server
systemctl status grafana-server | cat && sleep 5 && netstat -atunp | grep 3000 && sleep 5 

#Usuario e senha padrão admin admin 

#curl -X GET -H "Content-Type: application/json" 
# -X tipo de request GET, HEAD, POST e PUT
# -H header campo content-type
# -d data o que deve ser enviado 
# -s não exibe barra de progresso

#http://docs.grafana.org/http_api/data_source/

#Adicionando datasource prometheus via basic auth
curl -X POST -H "Content-Type: application/json" -d '{"name":"prometheus", "type":"prometheus", "url":"http://localhost:9090", "access":"proxy"}' http://admin:admin@localhost:3000/api/datasources

#Ou via API 
#http://docs.grafana.org/tutorials/api_org_token_howto/

#criar id 
#orgid=`curl -s -X POST -H "Content-Type: application/json" -d '{"name":"apiorg"}' http://admin:admin@localhost:3000/api/orgs | cut -d: -f3 | tr -d [=}=]`

#Criar chave api com direitos de admin
#keyadmin=`curl -s -X POST -H "Content-Type: application/json" -d '{"name":"apikeyadmincurl", "role": "Admin"}' http://admin:admin@localhost:3000/api/auth/keys | cut -d: -f3 | cut -d\" -f2`

#Guardar chave api
#echo $keyadmin > /root/.grafana_api_key 
#chmod 600 /root/.grafana_api_key

#Adicionando datasource
#curl -X POST -H "Authorization: Bearer $keyadmin" -H "Content-Type: application/json" -d '{"name":"prometheus", "type":"prometheus", "url":"http://localhost:9090", "access":"proxy"}' http://localhost:3000/api/datasources

#Apagar datasource 
#curl -X DELETE -H "Content-Type: application/json" http://admin:admin@localhost:3000/api/datasources/name/nomedatasource

#Adicionando dashboard
#wget -O /tmp/node.json "https://grafana.com/api/dashboards/1860/revisions/12/download"
#curl -X POST -H "Content-Type: application/json" -d '{"dashboard": {"id": 1860, "uid": null, "title": "Production Overview", "tags": [ "templated" ], "timezone": "browser", "schemaVersion": 16, "version": 0}, "folderId": 0, "overwrite": false} http://localhost:3000/api/dashboards/db
