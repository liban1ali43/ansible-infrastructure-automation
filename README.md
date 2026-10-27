# Ansible Infrastructure Automation Lab

## 📌 Project Overview
This project is a hands-on simulation of an enterprise-grade, segmented network environment. In secure enterprise setups (like banking or government), managed production servers are often not allowed direct access to the public internet. 

I built this lab to practice infrastructure automation in that exact scenario. The lab consists of a **Control Node** (which has outbound internet access to build environments and fetch packages) and **four isolated Managed Nodes** that rely entirely on the Control Node for packages and services.

### 🏗️ Lab Architecture
*   **Control Node (`server.lab.example.com`)**: Runs Ansible, hosts the custom Execution Environment (EE), the private container registry (with NFS storage), and the internal YUM repository.
*   **`servera`**: Isolated development node.
*   **`serverb` & `serverc`**: Isolated Apache web servers.
*   **`serverd`**: Isolated HAProxy load balancer.

---

## 🛠️ What I Built (The Workflow)

### 1. Custom Execution Environment (EE)
To ensure consistency across the lab, I didn't rely on local Python packages. I wrote a `Containerfile` based on the Red Hat AAP RHEL9 base image and executed automation using `ansible-navigator`.
*   Installed required system tools (`git`, `iputils`, `python3-pip`).
*   Installed Python dependencies (`netaddr`, `passlib`).
*   Installed Ansible collections (`amazon.aws`, `community.general`).
*   Hardened the image to run as a non-root user (`USER 1000`). 

### 2. Internal Package Repository (`/internal-yum-repo`)
Because the managed nodes are strictly isolated, they cannot reach Red Hat's CDN. 
*   Created a local RPM repository on the control node.
*   Wrote an executable setup script (`setup-repo.sh`) and an Ansible playbook to configure the managed nodes to use this internal repo as their only source for packages.

### 3. Private Container Registry with Persistent NFS Storage (`/private-registry`)
I automated the deployment of a local, secure container registry.
*   **Authentication & TLS**: Configured htpasswd for basic auth and generated self-signed certificates. Nginx acts as a reverse proxy on port 443.
*   **Container Management**: Used **Podman Quadlets** to manage the registry service via `systemd` natively.
*   **Persistent Storage**: To ensure container images survive node failures, I configured the registry's data directory to use an NFS-backed mount.
*   **Verification**: Successfully authenticated via `podman login` and pushed/pulled the custom EE image from a **separate virtual machine** (NFS Server) using configured `/etc/containers/registries.conf`.

### 4. Web Tier & Load Balancer (`/apache-webservers` & `/haproxy`)
*   Installed and configured Apache web servers on `serverb` and `serverc`.
*   Installed HAProxy on `serverd` to distribute traffic across the two web servers.
*   *Verified*: Ran repeated `curl` requests against the HAProxy IP and confirmed round-robin traffic distribution between the two Apache backends.

---

## 📂 Repository Structure
```text
ansible_lab/
├── Containerfile               # Custom EE definition
├── README.md                   # Project documentation
├── setup-repo.sh               # Script to expose internal repo
├── haproxy/                    # HAProxy load balancer configs
├── internal-yum-repo/          # Private RPM repo playbooks
├── private-registry/           # Registry, Nginx, TLS, NFS configs
├── apache-webservers/          # Apache web server playbooks
└── screenshots/                # Proof of execution and lab layout

🧠 Challenges & Lessons Learned
Building this in a segmented environment came with realistic roadblocks that required deep troubleshooting:

NFS and SELinux for Containers: When mounting the NFS share for the registry's data directory, the container failed to write to it. I had to explicitly enable the virt_use_nfs SELinux boolean (setsebool -P virt_use_nfs on) to allow the containerized service to read and write to the mount without disabling SELinux entirely.

The Port 80 Conflict (Nginx vs. Apache): During registry configuration, Apache was already occupying port 80. I commented out the default port 80 listener in /etc/nginx/nginx.conf and configured Nginx to use port 443 (TLS) as its main entry point, forcing all registry traffic to be encrypted.

Podman/Docker DNS Resolution: Diagnosed Docker Hub image-pull failures caused by DNS resolution errors from the lab DNS resolver. Used nslookup, getent, and curl to isolate the issue and restored image pulls by configuring Google Public DNS (8.8.8.8) via nmcli.

Ansible Vault: Used Vault (locker.yml) to manage registry passwords and htpasswd hashes so no plaintext secrets were committed.
