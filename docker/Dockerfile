# Use an official OpenJDK 17 as a base image, which is stable for Hadoop/Spark
FROM openjdk:17.0.1-jdk-slim

# Set maintainer label
LABEL maintainer="Elliot Huang <keep.it.sns@gmail.com>"

# Set ARGs for user and group to be created
ARG USER=hadoop
ARG UID=1000
ARG GID=1000

# Set environment variables for Hadoop, Spark, Java, and Python
ENV HADOOP_VERSION=3.4.2
ENV SPARK_VERSION=4.0.1
ENV HIVE_VERSION=4.1.0
ENV HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-aarch64-lean.tar.gz"
ENV SPARK_URL="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz"
ENV HIVE_URL="https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"

ENV JAVA_HOME=/usr/local/openjdk-17
ENV HADOOP_HOME=/opt/hadoop
ENV SPARK_HOME=/opt/spark
ENV HIVE_HOME=/opt/hive
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$HIVE_HOME/bin

# Define the location for Hadoop's PID files
ENV HADOOP_PID_DIR=/var/run/hadoop-pids

# Install dependencies: wget for downloading, ssh for hadoop scripts, python for pyspark
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    tini \
    gosu \
    openssh-server \
    openssh-client \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Download, verify, and install Hadoop
RUN wget -q "${HADOOP_URL}" -O /tmp/hadoop.tar.gz && \
    wget -q "${HADOOP_URL}.asc" -O /tmp/hadoop.tar.gz.asc && \
    wget -q "https://downloads.apache.org/hadoop/common/KEYS" -O /tmp/KEYS && \
    gpg --import /tmp/KEYS && \
    gpg --batch --verify /tmp/hadoop.tar.gz.asc /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    ln -s /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm /tmp/hadoop.tar.gz* /tmp/KEYS

# Download, verify, and install Spark
RUN wget -q "${SPARK_URL}" -O /tmp/spark.tgz && \
    wget -q "${SPARK_URL}.asc" -O /tmp/spark.tgz.asc && \
    wget -q "https://downloads.apache.org/spark/KEYS" -O /tmp/KEYS && \
    gpg --import /tmp/KEYS && \
    gpg --batch --verify /tmp/spark.tgz.asc /tmp/spark.tgz && \
    tar -xzf /tmp/spark.tgz -C /opt/ && \
    ln -s /opt/spark-${SPARK_VERSION}-bin-without-hadoop ${SPARK_HOME} && \
    rm /tmp/spark.tgz* /tmp/KEYS

# Download, verify and install Hive
RUN wget -q "${HIVE_URL}" -O /tmp/hive.tar.gz && \
    wget -q "${HIVE_URL}.asc" -O /tmp/hive.tar.gz.asc && \
    wget -q "https://downloads.apache.org/hive/KEYS" -O /tmp/KEYS && \
    gpg --import /tmp/KEYS && \
    gpg --batch --verify /tmp/hive.tar.gz.asc /tmp/hive.tar.gz && \
    tar -xzf /tmp/hive.tar.gz -C /opt/ && \
    ln -s /opt/apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} && \
    rm /tmp/hive.tar.gz

# Create a non-root user and group
RUN groupadd -g ${GID} ${USER} && \
    useradd -u ${UID} -g ${GID} -m -s /bin/bash ${USER}

# Configure Hadoop - core-site.xml, hdfs-site.xml, mapred-site.xml, yarn-site.xml
COPY --chown=${USER}:${USER} hadoop/core-site.xml $HADOOP_CONF_DIR/core-site.xml
COPY --chown=${USER}:${USER} hadoop/hdfs-site.xml $HADOOP_CONF_DIR/hdfs-site.xml
COPY --chown=${USER}:${USER} hadoop/mapred-site.xml $HADOOP_CONF_DIR/mapred-site.xml
COPY --chown=${USER}:${USER} hadoop/yarn-site.xml $HADOOP_CONF_DIR/yarn-site.xml
COPY --chown=${USER}:${USER} hadoop/hive-site.xml $HIVE_HOME/conf/hive-site.xml
COPY --chown=${USER}:${USER} spark-env.sh $SPARK_HOME/conf/spark-env.sh
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> $HADOOP_CONF_DIR/hadoop-env.sh

# Create hadoop log dir and set ownership
RUN mkdir -p ${HADOOP_HOME}/logs && chown -R ${USER}:${USER} ${HADOOP_HOME}/logs

# Create spark log dir and set ownership
RUN mkdir -p ${SPARK_HOME}/logs && chown -R ${USER}:${USER} ${SPARK_HOME}/logs

# Create spark work dir and set ownership
RUN mkdir -p ${SPARK_HOME}/work && chown -R ${USER}:${USER} ${SPARK_HOME}/work

# Create the PID directory and set its permissions
RUN mkdir -p $HADOOP_PID_DIR && chown -R ${USER}:${USER} $HADOOP_PID_DIR

# NameNode is formatted in entrypoint.sh

# Now, set the HOME env var and switch to the non-root user
ENV HOME=/home/${USER}
USER ${USER}
WORKDIR ${HOME}

# Add the user's local bin to the PATH for jupyter
ENV PATH="${HOME}/.local/bin:${PATH}"

# Configure SSH for passwordless login, required by Hadoop start scripts
RUN ssh-keygen -t rsa -P '' -f ${HOME}/.ssh/id_rsa && \
    cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys && \
    chmod 600 ${HOME}/.ssh/authorized_keys

# Configure SSH client to connect to localhost without prompts
RUN echo "Host localhost\n  StrictHostKeyChecking no" >> ${HOME}/.ssh/config

# Expose ports for HDFS, YARN, Spark, and Spark Master
EXPOSE 9870 9864 8088 8042 8888 7077 9000 8080

# Set the working directory for our project
WORKDIR ${HOME}/project

# Switch back to root to set up the entrypoint
USER root

# Copy the entrypoint script and give it execution permissions
# The --chown flag ensures the script is owned by the non-root user
COPY --chown=${USER}:${USER} entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use tini to properly manage processes and signals
# The entrypoint script will start all services
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command is to start jupyter lab
CMD ["bootstrap"]

