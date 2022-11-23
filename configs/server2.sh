#!/bin/bash

apt update -y
sudo apt  install awscli -y

ZK1="zk1.vijay4devops.co"
ZK2="zk2.vijay4devops.co"
ZK3="zk3.vijay4devops.co"
KAFKA2="kafka2.vijay4devops.co"
REGION="us-west-2"

#sudo apt  install jq -y

ZOOKEEPER_VERSION=3.7.1

apt install default-jdk -y

mkdir -p /zk && useradd -r -d /zk -s /usr/sbin/nologin zoo

mkdir -p /opt/zookeeper && \
    curl "https://dlcdn.apache.org/zookeeper/zookeeper-$ZOOKEEPER_VERSION/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz" \
    -o /opt/zookeeper/zookeeper.tar.gz && \
    mkdir -p /zk && cd /zk && \
    tar -xvzf /opt/zookeeper/zookeeper.tar.gz --strip 1

chown -R zoo:zoo /zk

sudo -u zoo mkdir -p /zk/data
sudo -u zoo mkdir -p /zk/data-log
sudo -u zoo mkdir -p /zk/logs

cat > /etc/systemd/system/zookeeper.service << EOF
[Unit]
Description=Zookeeper Daemon
Documentation=http://zookeeper.apache.org
Requires=network.target
After=network.target
[Service]
Type=forking
WorkingDirectory=/zk
User=zoo
Group=zoo
ExecStart=/bin/sh -c '/zk/bin/zkServer.sh start /zk/conf/zoo.cfg > /zk/logs/start-zk.log 2>&1'
ExecStop=/zk/bin/zkServer.sh stop /zk/conf/zoo.cfg
ExecReload=/zk/bin/zkServer.sh restart /zk/conf/zoo.cfg
TimeoutSec=30
Restart=on-failure
[Install]
WantedBy=default.target
EOF


systemctl daemon-reload
systemctl enable zookeeper

sudo cat > /zk/data/myid << EOF
2
EOF

string="$(aws ssm get-parameter --name "/Test/private-ip" --query "Parameter.Value" --output text --region $REGION)"
array=(`echo $string | sed 's/,/\n/g'`)
server1_private="$${array[0]}"
server2_private="$${array[1]}"
server3_private="$${array[2]}"

sudo cat > /zk/conf/zoo.cfg << EOF
tickTime=2000
initLimit=10
syncLimit=5
clientPort=2181
dataDir=/zk/data
dataLogDir=/zk/data-log
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1
server.1=$ZK1:2888:3888
server.2=0.0.0.0:2888:3888
server.3=$ZK3:2888:3888
EOF



############# KAFKA PUBLIC CONFIGURATION ##############

KAFKA_VERSION=3.2.0

mkdir -p /kafka && useradd -r -d /kafka -s /usr/sbin/nologin kafka

mkdir -p /opt/kafka && \
    curl "https://archive.apache.org/dist/kafka/$KAFKA_VERSION/kafka_2.13-$KAFKA_VERSION.tgz" \
    -o /opt/kafka/kafka.tar.gz && \
    mkdir -p /kafka && cd /kafka && \
    tar -xvzf /opt/kafka/kafka.tar.gz --strip 1

chown -R kafka:kafka /kafka
sudo -u kafka mkdir -p /kafka/log
sudo -u kafka mkdir -p /kafka/logs


cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Description=Apache Kafka Server
Documentation=http://kafka.apache.org/documentation.html
Requires=network.target
After=network.target
[Service]
Type=simple
WorkingDirectory=/kafka
User=kafka
Group=kafka
ExecStart=/bin/sh -c '/kafka/bin/kafka-server-start.sh /kafka/config/server.properties > /kafka/logs/start-kafka.log 2>&1'
ExecStop=/kafka/bin/kafka-server-stop.sh
TimeoutSec=30
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kafka

mv /kafka/config/server.properties /kafka/config/server.properties-backup

string="$(aws ssm get-parameter --name "/Test/public-ip" --query "Parameter.Value" --output text --region $REGION)"
array=(`echo $string | sed 's/,/\n/g'`)
server1_public="$${array[0]}"
server2_public="$${array[1]}"
server3_public="$${array[2]}"

sudo cat > /kafka/config/server.properties << EOF
broker.id=1
listeners=SSL://$KAFKA2:9092
advertised.listeners=SSL://$KAFKA2:9092
num.network.threads=3
num.io.threads=8
delete.topic.enable=true
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/kafka/kafka-logs
num.partitions=8
min.insync.replicas=1
default.replication.factor=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.retention.check.interval.ms=300000
zookeeper.connection.timeout.ms=18000
group.initial.rebalance.delay.ms=0
advertised.host.name=localhost
zookeeper.connect=$ZK1:2181,$ZK2:2181,$ZK3:2181
ssl.keystore.password=password
ssl.key.password=password
ssl.truststore.password=password
ssl.client.auth=required
ssl.enabled.protocols=TLSv1.2
ssl.keystore.type=JKS
ssl.truststore.type=JKS
ssl.endpoint.identification.algorithm=HTTPS
security.inter.broker.protocol=SSL
ssl.keystore.location=/certs/$KAFKA2.keystore.jks
ssl.truststore.location=/certs/$KAFKA2.truststore.jks
authorizer.class.name=kafka.security.authorizer.AclAuthorizer
allow.everyone.if.no.acl.found=false
super.users=User:CN=kafka1.vijay4devops.co,OU=Devops,O=Vijay Pvt Ltd,L=Hyderabad,C=IN;User:CN=kafka2.vijay4devops.co,OU=Devops,O=Vijay Pvt Ltd,L=Hyderabad,C=IN;User:CN=kafka3.vijay4devops.co,OU=Devops,O=Vijay Pvt Ltd,L=Hyderabad,C=IN;User:CN=client,OU=Devops,O=Vijay Pvt Ltd,L=Hyderabad,C=IN
EOF

######################################################### URLS #######################################################


ENV="Test"
KAFKA="kafka2"
ZK="zk2"
name1="$(aws ssm get-parameter --name "/$ENV/$KAFKA/url" --query "Parameter.Value" --output text --region $REGION)"
name2="$(aws ssm get-parameter --name "/$ENV/$ZK/url" --query "Parameter.Value" --output text --region $REGION)"
touch /home/ubuntu/urls.txt
sudo chown ubuntu:ubuntu /home/ubuntu/urls.txt
echo "$name1" > /home/ubuntu/urls.txt
echo "$name2" >>/home/ubuntu/urls.txt


###########################################################  certs   ##############################################
#CA certs pulling to broker server
mkdir /certs && cd /certs
ENV="Test"
KAFKA="kafka"

aws ssm get-parameter --name "/$ENV/$KAFKA/crt" --with-decryption --query "Parameter.Value" --output text --region $REGION > ca.crt
aws ssm get-parameter --name "/$ENV/$KAFKA/key" --with-decryption --query "Parameter.Value" --output text --region $REGION > ca.key


#generating server,client trustore and keystore
CERTS_PATH="/certs"
PASS="password"
CA_CERT="/certs/ca.crt"
CA_KEY="/certs/ca.key"

elements="$KAFKA2","client"

IFS=',' read -r -a array <<< "$elements"
for i in "$${array[@]}"
do
        if [[ ! -f $CERTS_PATH/$i.keystore.jks ]] && [[ ! -f $CERTS_PATH/$i.truststore.jks ]];then
        printf "Creating cert and keystore for $KAFKA..."
        # Create keystores
        keytool -genkey -noprompt \
                             -alias $i \
                             -dname "CN=$i, OU=Devops, O=Vijay Pvt Ltd, L=Hyderabad, C=IN" \
                             -keystore $CERTS_PATH/$i.keystore.jks \
                             -keyalg RSA \
                             -storepass $PASS \
                             -keypass $PASS  >/dev/null 2>&1

        # Create CSR, sign the key and import back into keystore
        keytool -keystore $CERTS_PATH/$i.keystore.jks -alias $i -certreq -file /tmp/$i.csr -storepass $PASS -keypass $PASS >/dev/null 2>&1

        openssl x509 -req -CA $CA_CERT -CAkey $CA_KEY -in /tmp/$i.csr -out /tmp/$i-ca-signed.crt -days 1825 -CAcreateserial -passin pass:$PASS  >/dev/null 2>&1

        keytool -keystore $CERTS_PATH/$i.keystore.jks -alias CARoot -import -noprompt -file $CA_CERT -storepass $PASS -keypass $PASS >/dev/null 2>&1

        keytool -keystore $CERTS_PATH/$i.keystore.jks -alias $i -import -file /tmp/$i-ca-signed.crt -storepass $PASS -keypass $PASS >/dev/null 2>&1

        # Create truststore and import the CA cert.
        keytool -keystore $CERTS_PATH/$i.truststore.jks -alias CARoot -import -noprompt -file $CA_CERT -storepass $PASS -keypass $PASS >/dev/null 2>&1
    echo " OK!"
       else
           printf "Keystore: $i.keystore.jks and truststore: $i.truststore.jks already exist..skip creating it.."
           echo " OK!"
    fi
done

chown -R kafka:kafka /certs/
##################################################### clients properties ###############################################
sudo cat > /certs/client.properties << EOF
bootstrap.servers=kafka1.vijay4devops.co:9092,kafka2.vijay4devops.co:9092,kafka3.vijay4devops.co:9092
security.protocol=SSL
ssl.truststore.location=/certs/client.truststore.jks
ssl.truststore.password=password
ssl.keystore.location=/certs/client.keystore.jks
ssl.keystore.password=password
ssl.key.password=password
EOF

chown -R kafka:kafka /certs/
#####################################################################################################################

sudo systemctl start zookeeper
sudo systemctl start kafka
