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
        npm \
        python3-pip \
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

    DEFAULT_USER=$(getent passwd 1000 | cut -d: -f1)
    usermod -aG docker $DEFAULT_USER

    echo "Docker installed"
}


install_jenkins() {

    echo "Installing Jenkins using WAR file..."

    useradd -m -d /var/lib/jenkins -s /bin/bash jenkins || true

    # Create directories
    mkdir -p /opt/jenkins
    mkdir -p /var/lib/jenkins
    chown -R jenkins:jenkins /opt/jenkins /var/lib/jenkins

    # Download latest Jenkins WAR (LTS)
    wget -O /opt/jenkins/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war

    chown jenkins:jenkins /opt/jenkins/jenkins.war

    # Create systemd service
    cat <<EOF > /etc/systemd/system/jenkins.service
[Unit]
Description=Jenkins CI
After=network.target

[Service]
User=jenkins
WorkingDirectory=/var/lib/jenkins
ExecStart=/usr/bin/java -jar /opt/jenkins/jenkins.war --httpPort=8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reexec
    systemctl daemon-reload

    systemctl enable jenkins
    systemctl start jenkins

    echo "Jenkins installed successfully"
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

install_kubectl() {

    echo "Installing kubectl..."

    # Default to the latest stable kubectl if not pinned via env var.
    local KUBECTL_VERSION="${KUBECTL_VERSION:-}"
    if [ -z "$KUBECTL_VERSION" ]; then
        KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    fi

    local ARCH
    ARCH="$(dpkg --print-architecture)"

    case "$ARCH" in
        amd64|arm64)
            ;;
        *)
            echo "Unsupported architecture for kubectl: $ARCH"
            exit 1
            ;;
    esac

    curl -fsSLo /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"

    chmod +x /usr/local/bin/kubectl

    kubectl version --client --output=yaml >/dev/null 2>&1 || true
}

install_helm() {

    echo "Installing Helm..."

    # Install the latest Helm 3 release. Version pinning can be done by overriding HELM_INSTALL_DIR.
    HELM_INSTALL_DIR="/usr/local/bin" \
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    helm version >/dev/null 2>&1 || true
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
    install_terraform 
    install_kubectl
    install_helm
    detect_cloud 
    install_cloud_cli 
    #install_jenkins 

}

main

echo " Bootstrap Completed Successfully"
echo " Logs: ${LOG_FILE}"
