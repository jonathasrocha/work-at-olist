#!/bin/bash -e
#aws s3 mb s3://workolistexample

#create cluster with paramets passed from enviroment variable
aws redshift create-cluster --cluster-identifier $cluster_name --node-type ds2.xlarge --db-name $redshift_dbname --master-username $redshift_username --master-user-password $redshift_password 

#print mensage to screen
echo "Waiting for redshift endpoint"

#Waiting for the cluster to stay available
aws redshift wait cluster-available --cluster-indentifier $cluster_name

#get the endpoint to connect and create datawarehouse
endpoint=$(aws redshift describe-clusters --cluster-identifier $cluster_name --query "Clusters[*].Endpoint.Address" --output text)
port=$(aws redshift describe-clusters --cluster-identifier $cluster_name --query "Clusters[*].Endpoint.Port" --output text)

#connect to just cluster created 
psql --host=$endpoint --port=$port --username=$redshift_username --dbname=$redshift_dbname -f model.sql

psql -f model.sql