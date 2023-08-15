#!/usr/bin/sh

## Öncelikle sunuculara erlang ve rabbitmq kurulumunu yapıyoruz.
sudo apt-get install -y erlang rabbitmq-server
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

## Proje, monitoring ve admin ekipleri için kullanıcılar oluşturuyoruz. 
sudo rabbitmqctl add_user admin AdminPassRabbitMQ
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
sudo rabbitmqctl add_vhost app-qa1
