#!/bin/bash

set -e

# Ensure the project directories are owned by the hadoop user at the start
chown -R hadoop:hadoop /project

# Start SSH server for Hadoop daemons
service ssh start

# Format NameNode if it's not already formatted
NAMENODE_DIR="/project/hdfs/namenode"
if [ ! -d "$NAMENODE_DIR" ] || [ -z "$(ls -A "$NAMENODE_DIR")" ]; then
  echo "NameNode directory not found or is empty. Formatting HDFS..."
  gosu hadoop $HADOOP_HOME/bin/hdfs namenode -format
  echo "HDFS formatted."
else
  echo "NameNode directory found. Skipping HDFS format."
fi

# Start Hadoop services
echo "Starting HDFS..."
gosu hadoop $HADOOP_HOME/sbin/start-dfs.sh
echo "Starting YARN..."
gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh

echo "Starting Spark Master and Worker..."
gosu hadoop $SPARK_HOME/sbin/start-master.sh
gosu hadoop $SPARK_HOME/sbin/start-worker.sh spark://localhost:7077

echo "Waiting for HDFS to exit safemode..."
while ! gosu hadoop hdfs dfsadmin -safemode get | grep -q "Safe mode is OFF"; do
  echo "Waiting for HDFS to exit safemode..."
  sleep 5
done

echo "Initializing Hive directories in HDFS..."
gosu hadoop hdfs dfs -mkdir -p /user/hive/warehouse
gosu hadoop hdfs dfs -mkdir -p /tmp
gosu hadoop hdfs dfs -chmod g+w /user/hive/warehouse
gosu hadoop hdfs dfs -chmod g+w /tmp

echo "Hadoop & Spark Environment is Ready!"

gosu hadoop hadoop fs -mkdir -p /project/data
gosu hadoop hadoop fs -put /project/data/arxiv-metadata-oai-snapshot.json /project/data

# Initialize Hive Metastore if it doesn't exist
METASTORE_DB_DIR="/project/metastore_db"
if [ ! -d "$METASTORE_DB_DIR" ]; then
  echo "Metastore database not found. Initializing Hive schema..."
  gosu hadoop $HIVE_HOME/bin/schematool -dbType derby -initSchema
  echo "Hive schema initialized."
else
  echo "Hive metastore database already exists."
fi


# Check the command passed to the script
if [ "$1" = "bootstrap" ]; then
    # Keep the container running indefinitely
    echo "Container is running in background service mode. Connect with a client."
    tail -f /dev/null
else
    # Execute any other command as hadoop user
    exec gosu hadoop "$@"
fi
