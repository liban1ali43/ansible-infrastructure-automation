FROM registry.redhat.io/ansible-automation-platform-26/ee-supported-rhel9:latest

USER root

# 1. Install python3-pip along with required system tools
RUN microdnf install -y git iputils python3-pip && microdnf clean all

# 2. Install Python packages (with warning suppressed)
RUN python3 -m pip install --no-cache-dir --root-user-action=ignore \
    netaddr \
    passlib

# 3. Install required Ansible collections
RUN ansible-galaxy collection install \
    amazon.aws \
    community.general

USER 1000

