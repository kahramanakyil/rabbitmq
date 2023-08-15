#!/usr/bin/sh

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get update -y

sudo apt-get install curl gnupg apt-transport-https -y

## Team RabbitMQ's main signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
## Cloudsmith: modern Erlang repository
curl -1sLf https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null
## Cloudsmith: RabbitMQ repository
curl -1sLf https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Provides modern Erlang/OTP releases
##
deb [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu bionic main
deb-src [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.E495BB49CC4BBE5B.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu bionic main

## Provides RabbitMQ
##
deb [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu bionic main
deb-src [signed-by=/usr/share/keyrings/io.cloudsmith.rabbitmq.9F4587F226208342.gpg] https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu bionic main
EOF

## Update package indices
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get update -y

## Install Erlang packages
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install rabbitmq-server and its dependencies
sudo apt-get update -y

## Öncelikle sunuculara erlang ve rabbitmq kurulumunu yapıyoruz.
apt install -y erlang rabbitmq-server
systemctl stop rabbitmq-server.service

## Data ve log dosyaları için ayrı bir path oluşturup, rabbitmq userına gerekli yetkileri veriyoruz.
mkdir -p /rabbitmq/rabbit_data && mkdir -p /rabbitmq/rabbit_log && chown -R rabbitmq:rabbitmq /rabbitmq/* && chmod 755 /rabbitmq/*

## RabbitMq Mnesia database ve log pathi rabbitmq-env.conf dosyasına yazdırılır.
cat > /etc/rabbitmq/rabbitmq-env.conf << EOF
RABBITMQ_MNESIA_BASE=/rabbitmq/rabbit_data
RABBITMQ_LOG_BASE=/rabbitmq/rabbit_log
EOF

## RabbitMq clusterin düzgün bir şekilde çalışabilmesi için .erlang.cookie dosyalarının eşlenik olması gerekmektedir. Bu sebeple tüm sunuculardaki aynı dosyanın içine 'MYCOOKIEVALUE' değerini giriyoruz ve rabbitmq userına buraya yetki veriyoruz.
echo 'MYCOOKIEVALUE' | tee /rabbitmq/rabbit_data/.erlang.cookie
chown rabbitmq:rabbitmq /rabbitmq/rabbit_data/.erlang.cookie
chmod 400 /rabbitmq/rabbit_data/.erlang.cookie

## RabbitMq servisi enable ve start edilip, ardından cluster ayarları için stop duruma çekilmelidir.
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl stop_app
rabbitmqctl reset

## Buradaki rabbit@Cluster_Name ilk sunucunun adıdır. Biz playbookumuzda burayı parametre olarka verdiğimizden 3.parametreye denk olduğunu göstermek için "$3" işaretini kullanıyoruz.
rabbitmqctl join_cluster rabbit@$3
systemctl start rabbitmq-server.service
rabbitmqctl start_app
rabbitmq-plugins enable rabbitmq_management

## Proje, monitoring ve admin ekipleri için kullanıcılar oluşturuyoruz. "$1" ve "$2" parametreleri playbooktan gelmektedir. User ve password için kullanılmıştır.
rabbitmqctl add_user username password
rabbitmqctl set_user_tags username administrator
rabbitmqctl add_user username_monitoring password
rabbitmqctl set_user_tags username_monitoring monitoring
rabbitmqctl add_user $1 $2
rabbitmqctl set_user_tags $1 administrator
rabbitmqctl set_permissions -p / $1 ".*" ".*" ".*"
rabbitmqctl set_permissions -p / username ".*"
