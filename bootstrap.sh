#!/bin/bash

set -e

LOG_FILE="/var/log/bootstrap.log"

exec > >(tee -a ${LOG_FILE}) 2>&1

echo " VM Bootstrap Started"


update_system() {
    echo "Updating system..."
    apt-get update -y
    apt-get upgrade -y
}


install_base_tools() {

    echo "Installing base utilities..."

    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        jq \
        vim \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common
}


install_java() {

    echo "Installing OpenJDK..."

    apt-get install -y openjdk-17-jdk

    java -version
}


install_docker() {

    echo "Installing Docker..."

    mkdir -p /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ubuntu

    echo "Docker installed"
}


install_jenkins() {

    echo "Installing Jenkins..."

    apt-get install -y fontconfig openjdk-17-jre

    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | gpg --dearmor \
    | tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] \
    https://pkg.jenkins.io/debian-stable binary/" \
    | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    apt-get update -y
    apt-get install -y jenkins

    systemctl enable jenkins
    systemctl start jenkins

    echo "Jenkins installed"
}


install_terraform() {

    echo "Installing Terraform..."

    wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor | \
        tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com \
        $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/hashicorp.list

    apt-get update -y

    apt-get install -y terraform
}


detect_cloud() {

    echo "Detecting cloud provider..."

    if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        CLOUD="aws"

    elif curl -s -H Metadata:true --connect-timeout 2 \
        "http://169.254.169.254/metadata/instance?api-version=2021-02-01" >/dev/null 2>&1; then
        CLOUD="azure"

    elif curl -s --connect-timeout 2 http://metadata.google.internal >/dev/null 2>&1; then
        CLOUD="gcp"

    else
        CLOUD="unknown"
    fi

    echo "Detected cloud: $CLOUD"
}


install_cloud_cli() {

    if [ "$CLOUD" = "aws" ]; then

        echo "Installing AWS CLI..."

        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
        unzip awscliv2.zip
        ./aws/install


    elif [ "$CLOUD" = "azure" ]; then

        echo "Installing Azure CLI..."

        curl -sL https://aka.ms/InstallAzureCLIDeb | bash


    elif [ "$CLOUD" = "gcp" ]; then

        echo "Installing Google Cloud CLI..."

        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
        http://packages.cloud.google.com/apt cloud-sdk main" \
        | tee /etc/apt/sources.list.d/google-cloud-sdk.list

        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

        apt-get update -y
        apt-get install -y google-cloud-cli

    else

        echo "Unknown cloud provider. Skipping CLI installation."

    fi
}


main() {

    update_system
    install_base_tools
    install_java
    install_docker
    install_jenkins
    install_terraform
    detect_cloud
    install_cloud_cli

}

main

echo " Bootstrap Completed Successfully"
echo " Logs: ${LOG_FILE}"
