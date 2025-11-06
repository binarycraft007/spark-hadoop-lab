#!/usr/bin/env bash

# This is the crucial setting. It tells the Spark Master to listen on all
# network interfaces inside the container, which allows Docker's port mapping
# to forward traffic from your host machine to it.
export SPARK_MASTER_HOST=0.0.0.0
export SPARK_DIST_CLASSPATH=$(/opt/hadoop/bin/hadoop classpath)
