# Private-terraform-kafka-zk-3node-cluster-SSL


This document provides steps to configure 3 node zookeeper and kafka cluster on AWS using Terraform
- 3 instances will be created, where each instance contains kafka and zookeeper




![image](https://user-images.githubusercontent.com/66196388/204148537-1f432b05-9b13-4f0e-9ace-4961434faf1b.png)



### Please note the following things before you start working on this.

- install Terraform in Local/aws jump Server
- in /home/ubuntu/ca the private ca files will created and pushed to ssm parameterstore

```
sudo apt update -y
sudo apt install awscli -y
sudo apt install wget unzip
pwd
/home/ubuntu
mkdir terraform && cd terraform

cat <<EOF >>/home/ubuntu/terraform/terraform-install.sh
#!/bin/sh
touch terraform-install.sh
TER_VER=`curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | cut -d: -f2 | tr -d \"\,\v | awk '{$1=$1};1'`
sudo wget https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip
sudo unzip terraform_${TER_VER}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
EOF

chmod 755 terraform-install.sh
bash terraform-install.sh
which terraform
terraform --version
 ```

 ```
git clone https://github.com/vijay2181/terraform-kafka-zk-3node-cluster-SSL.git
```

### Please note that we are using only private aws ips for kafka brokers and zookeeper

- We need a public/private hosted zone on AWS Route 53, create it and note the hosted zone id

- Go to the Route 53 console and create a new Public Hosted Zone with public domain(example.com), transfer the name servers into aws route 53 if your doamin is managed by other provider

- And update provider’s DNS records (this step can vary based on your DNS provider). Depending on our DNS provider, the change will take a few minutes to hours. After that, we will be able to manage our domain from AWS Route 53


In variables.tf file change the variables According to your need
- ami-id
- region
- instance_type
- keypair
- username
- profile
- instance_count
- userdata files
- public_hosted_zone_id

- in config/userdata files fill all fields according to your need


```
terraform init
terraform plan
terraform apply
```



when all instances are up and running

```

- get into any broker and execute the following commands
- in each broker, truststore and keystore files are created by pulling same CA certs from ssm parameterstore which signs all broker client and server certs so that they are mutually authenticative

zookeeper logs:-
================
nc -z -v <private_ip> 2181
cd /zk/logs
tail -n 20 zookeeper-zoo-server-ip-172-31-13-78.out
to know who is leader in zookeeper cluster:-
=============================================
/zk/bin/zkServer.sh status
to list number of brokers:-
===========================
- GOTO ANY NODE EX:- NODE1
/zk/bin/zkCli.sh -server localhost:2181
If it is successful, you can see the Zk client running as:
WATCHER::
WatchedEvent state:SyncConnected type:None path:null
[zk: localhost:2181(CONNECTED) 0]
- it is connected to broker id 0
From here you can explore the broker details using various commands:
ls /brokers/ids
[zk: localhost:2181(CONNECTED) 0] ls /brokers/ids
[0, 1, 2]
kafka logs:-
============
tail -n 20 /kafka/logs/server.log
nc -z -v <private_ip> 9092
create topic:-
==============
/kafka/bin/kafka-topics.sh --create --if-not-exists --bootstrap-server kafka1.vijay4devops.co:9092,kafka2.vijay4devops.co:9092,kafka3.vijay4devops.co:9092 --command-config /certs/client.properties --replication-factor 3 --partitions 3 --topic vijay-test-topic

/kafka/bin/kafka-topics.sh --describe --topic vijay-test-topic --bootstrap-server kafka1.vijay4devops.co:9092,kafka2.vijay4devops.co:9092,kafka3.vijay4devops.co:9092 --command-config /certs/client.properties

Topic: vijay-test-topic TopicId: wb96soPkRgetTPohNd_jGg PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=1
        Topic: vijay-test-topic Partition: 0    Leader: 2       Replicas: 2,1,0 Isr: 2,1,0
        Topic: vijay-test-topic Partition: 1    Leader: 1       Replicas: 1,0,2 Isr: 1,0,2
        Topic: vijay-test-topic Partition: 2    Leader: 0       Replicas: 0,2,1 Isr: 0,2,1

```