#!/bin/bash
PASS="password"
mkdir -p /home/ubuntu/ca
echo " OK!"
CA_CERT=/home/ubuntu/ca/kafka-ca.crt
CA_KEY=/home/ubuntu/ca/kafka-ca.key

# Generate CA key
if [[ ! -f $CA_CERT ]] && [[ ! -f $CA_KEY ]];then
openssl req -new -x509 -keyout $CA_KEY -out $CA_CERT -days 3650 -subj '/CN=Kafka CA/OU=Devops/O=Vijay Pvt Ltd/L=Hyderabad/C=IN' -passin pass:$PASS -passout pass:$PASS >/dev/null 2>&1
echo " OK!"
else
echo "CA certs already exists - Skip creating it.."
fi


AWS_REGION="us-west-2"
ENV="Test"
LOCAL_PROFILE="test"
SERVICE="kafka"
SSL="true"
if [[ $SERVICE == "kafka" ]] && [[ $SSL == "true" ]];then
for file in crt key; do
   printf "uploading CA $file cert to Parameterstore...."
   aws ssm put-parameter --profile $LOCAL_PROFILE\
    --region $AWS_REGION \
    --name /$ENV/$SERVICE/$file \
    --type SecureString \
    --key-id alias/aws/ssm \
    --value "$(cat /home/ubuntu/ca/kafka-ca.$file)" \
	--overwrite
   echo "OK!"
done
fi