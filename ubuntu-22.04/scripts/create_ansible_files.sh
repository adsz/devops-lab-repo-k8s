#!/bin/bash

# Script to create/update Ansible files for Kubernetes setup with package upgrades
# Directory: /repos/devops-lab-new/devops-lab-repo-k8s/ubuntu-22.04
# Fixes sysctl error, containerd directory error, and comments out SSH settings task

# Base directory
BASE_DIR="/repos/devops-lab-new/devops-lab-repo-k8s/ubuntu-22.04"

# Create base directory if it doesn't exist
mkdir -p "$BASE_DIR"

# Create role directories
mkdir -p "$BASE_DIR/roles/common/defaults"
mkdir -p "$BASE_DIR/roles/common/tasks"
mkdir -p "$BASE_DIR/roles/common/handlers"
mkdir -p "$BASE_DIR/roles/k8s-master/defaults"
mkdir -p "$BASE_DIR/roles/k8s-master/vars"
mkdir -p "$BASE_DIR/roles/k8s-master/tasks"
mkdir -p "$BASE_DIR/roles/k8s-master/handlers"
mkdir -p "$BASE_DIR/roles/k8s-master/templates"
mkdir -p "$BASE_DIR/roles/k8s-worker/defaults"
mkdir -p "$BASE_DIR/roles/k8s-worker/vars"
mkdir -p "$BASE_DIR/roles/k8s-worker/tasks"
mkdir -p "$BASE_DIR/roles/k8s-worker/handlers"
mkdir -p "$BASE_DIR/roles/k8s-worker/templates"

# Create master-playbook.yml
cat << 'EOF' > "$BASE_DIR/master-playbook.yml"
---
- name: Configure Kubernetes master node
  hosts: k8s_masters
  become: yes
  roles:
    - { role: common, tags: [packages, security, vagrant_removal] }
    - { role: k8s-master, tags: kubernetes }
EOF

# Create worker-playbook.yml
cat << 'EOF' > "$BASE_DIR/worker-playbook.yml"
---
- name: Configure Kubernetes worker nodes
  hosts: k8s_workers
  become: yes
  roles:
    - { role: common, tags: [packages, security, vagrant_removal] }
    - { role: k8s-worker, tags: kubernetes }
EOF

# Create inventory.yml
cat << 'EOF' > "$BASE_DIR/inventory.yml"
---
all:
  children:
    k8s_masters:
      hosts:
        master_node:
          ansible_host: 192.168.0.180
          ansible_user: ansible
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
    k8s_workers:
      hosts:
        worker_node_1:
          ansible_host: 192.168.0.181
          ansible_user: ansible
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
        worker_node_2:
          ansible_host: 192.168.0.182
          ansible_user: ansible
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
EOF

# Create common/defaults/main.yml
cat << 'EOF' > "$BASE_DIR/roles/common/defaults/main.yml"
---
# Default settings for common role
apt_cache_valid_time: 3600
ssh_permit_root_login: "no"
ssh_password_authentication: "no"
ssh_allowed_users:
  - ansible
  - ubuntu
ufw_allowed_ports:
  - port: 22
    proto: tcp
    comment: SSH
fail2ban_maxretry: 3
fail2ban_findtime: 600
fail2ban_bantime: 3600
EOF

# Create common/tasks/main.yml
cat << 'EOF' > "$BASE_DIR/roles/common/tasks/main.yml"
---
# Common setup tasks for all nodes
- name: Update system packages
  include_tasks: packages.yml
  tags: packages

- name: Remove vagrant user
  include_tasks: vagrant_removal.yml
  tags: vagrant_removal

- name: Apply security hardening
  include_tasks: security.yml
  tags: security
EOF

# Create common/tasks/packages.yml
cat << 'EOF' > "$BASE_DIR/roles/common/tasks/packages.yml"
---
# Update and upgrade system packages
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: "{{ apt_cache_valid_time }}"
  register: apt_update
  retries: 3
  delay: 5
  until: apt_update is success
  tags: packages

- name: Upgrade all packages
  apt:
    upgrade: dist
    autoremove: yes
    autoclean: yes
  register: apt_upgrade
  retries: 3
  delay: 5
  until: apt_upgrade is success
  tags: packages
EOF

# Create common/tasks/security.yml
cat << 'EOF' > "$BASE_DIR/roles/common/tasks/security.yml"
---
# Apply security hardening to the system
- name: Install security packages
  apt:
    name:
      - ufw
      - fail2ban
      - unattended-upgrades
    state: present
  tags: security

# - name: Configure SSH settings
#   lineinfile:
#     path: /etc/ssh/sshd_config
#     regexp: "{{ item.regexp }}"
#     line: "{{ item.line }}"
#     state: present
#     validate: 'sshd -t -f %s'
#   loop:
#     - { regexp: '^#?PermitRootLogin', line: 'PermitRootLogin {{ ssh_permit_root_login }}' }
#     - { regexp: '^#?PasswordAuthentication', line: 'PasswordAuthentication {{ ssh_password_authentication }}' }
#     - { regexp: '^#?PubkeyAuthentication', line: 'PubkeyAuthentication yes' }
#     - { regexp: '^#?AllowUsers', line: 'AllowUsers {{ ssh_allowed_users | join(" ") }}' }
#   notify: restart_ssh
#   tags: security

- name: Enable UFW and allow specified ports
  ufw:
    state: enabled
    policy: deny
    rule: allow
    port: "{{ item.port }}"
    proto: "{{ item.proto }}"
    comment: "{{ item.comment | default(omit) }}"
  loop: "{{ ufw_allowed_ports }}"
  tags: security

- name: Enable unattended upgrades
  command: dpkg-reconfigure --priority=low unattended-upgrades
  args:
    creates: /etc/apt/apt.conf.d/20auto-upgrades
  tags: security

- name: Configure fail2ban for SSH
  copy:
    content: |
      [sshd]
      enabled = true
      maxretry = {{ fail2ban_maxretry }}
      findtime = {{ fail2ban_findtime }}
      bantime = {{ fail2ban_bantime }}
    dest: /etc/fail2ban/jail.d/sshd.conf
    mode: '0644'
  notify: restart_fail2ban
  tags: security
EOF

# Create common/tasks/vagrant_removal.yml
cat << 'EOF' > "$BASE_DIR/roles/common/tasks/vagrant_removal.yml"
---
# Remove vagrant user and associated files
- name: Remove vagrant user
  user:
    name: vagrant
    state: absent
    remove: yes
    force: yes
  ignore_errors: yes
  tags: vagrant_removal

- name: Ensure vagrant is removed from /etc/passwd
  lineinfile:
    path: /etc/passwd
    regexp: '^vagrant:'
    state: absent
  ignore_errors: yes
  tags: vagrant_removal

- name: Ensure vagrant is removed from /etc/shadow
  lineinfile:
    path: /etc/shadow
    regexp: '^vagrant:'
    state: absent
  ignore_errors: yes
  tags: vagrant_removal

- name: Ensure vagrant is removed from /etc/group
  lineinfile:
    path: /etc/group
    regexp: '^vagrant:'
    state: absent
  ignore_errors: yes
  tags: vagrant_removal

- name: Remove vagrant home directory
  file:
    path: /home/vagrant
    state: absent
  ignore_errors: yes
  tags: vagrant_removal
EOF

# Create common/handlers/main.yml
cat << 'EOF' > "$BASE_DIR/roles/common/handlers/main.yml"
---
- name: Restart SSH
  systemd:
    name: ssh
    state: restarted
  listen: restart_ssh

- name: Restart fail2ban
  systemd:
    name: fail2ban
    state: restarted
  listen: restart_fail2ban
EOF

# Create k8s-master/defaults/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/defaults/main.yml"
---
# Default Kubernetes settings
kubernetes_version: "1.29"
pod_network_cidr: "10.244.0.0/16"
control_plane_endpoint: "192.168.0.180:6443"
containerd_sandbox_image: "registry.k8s.io/pause:3.8"
EOF

# Create k8s-master/vars/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/vars/main.yml"
---
# Role-specific constants
kubernetes_apt_key_url: "https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/Release.key"
kubernetes_apt_repo: "deb https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/ /"
flannel_manifest_url: "https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
EOF

# Create k8s-master/tasks/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/tasks/main.yml"
---
# Configure Kubernetes master node
- name: Include common role for shared setup
  include_role:
    name: common
  tags: [packages, security, vagrant_removal]

- name: Configure Kubernetes master
  include_tasks: kubernetes.yml
  tags: kubernetes
EOF

# Create k8s-master/tasks/kubernetes.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/tasks/kubernetes.yml"
---
# Configure Kubernetes master node with kubeadm
- name: Install dependencies
  apt:
    name:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
    state: present
  tags: kubernetes

- name: Install containerd
  apt:
    name: containerd
    state: present
  tags: kubernetes

- name: Ensure containerd configuration directory exists
  file:
    path: /etc/containerd
    state: directory
    mode: '0755'
  tags: kubernetes

- name: Configure containerd
  template:
    src: containerd-config.toml.j2
    dest: /etc/containerd/config.toml
    mode: '0644'
  notify: restart_containerd
  tags: kubernetes

- name: Enable and start containerd
  systemd:
    name: containerd
    enabled: yes
    state: started
  tags: kubernetes

- name: Add Kubernetes apt key
  apt_key:
    url: "{{ kubernetes_apt_key_url }}"
    state: present
  tags: kubernetes

- name: Add Kubernetes apt repository
  apt_repository:
    repo: "{{ kubernetes_apt_repo }}"
    state: present
    filename: kubernetes
  tags: kubernetes

- name: Install Kubernetes components
  apt:
    name:
      - kubeadm={{ kubernetes_version }}.*
      - kubelet={{ kubernetes_version }}.*
      - kubectl={{ kubernetes_version }}.*
    state: present
    update_cache: yes
  tags: kubernetes

- name: Hold Kubernetes packages
  dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubeadm
    - kubelet
    - kubectl
  tags: kubernetes

- name: Disable swap
  command: swapoff -a
  when: ansible_swaptotal_mb > 0
  changed_when: ansible_swaptotal_mb > 0
  tags: kubernetes

- name: Remove swap from /etc/fstab
  lineinfile:
    path: /etc/fstab
    regexp: '^.*\sswap\s'
    state: absent
  tags: kubernetes

- name: Load kernel modules
  modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - overlay
    - br_netfilter
  tags: kubernetes

- name: Persist kernel modules
  copy:
    content: |
      overlay
      br_netfilter
    dest: /etc/modules-load.d/containerd.conf
    mode: '0644'
  tags: kubernetes

- name: Configure sysctl for Kubernetes
  template:
    src: kubernetes-sysctl.conf.j2
    dest: /etc/sysctl.d/99-kubernetes.conf
    mode: '0644'
  tags: kubernetes

- name: Apply sysctl settings
  command: sysctl --system
  changed_when: true
  tags: kubernetes

- name: Initialize Kubernetes master node
  command: >
    kubeadm init
    --pod-network-cidr={{ pod_network_cidr }}
    --control-plane-endpoint={{ control_plane_endpoint }}
  args:
    creates: /etc/kubernetes/admin.conf
  register: kubeadm_init
  tags: kubernetes

- name: Create kube config directory for ansible user
  file:
    path: /home/ansible/.kube
    state: directory
    owner: ansible
    group: ansible
    mode: '0700'
  tags: kubernetes

- name: Copy admin.conf for ansible user
  copy:
    src: /etc/kubernetes/admin.conf
    dest: /home/ansible/.kube/config
    owner: ansible
    group: ansible
    mode: '0600'
    remote_src: yes
  tags: kubernetes

- name: Create kube config directory for ubuntu user
  file:
    path: /home/ubuntu/.kube
    state: directory
    owner: ubuntu
    group: ubuntu
    mode: '0700'
  tags: kubernetes

- name: Copy admin.conf for ubuntu user
  copy:
    src: /etc/kubernetes/admin.conf
    dest: /home/ubuntu/.kube/config
    owner: ubuntu
    group: ubuntu
    mode: '0600'
    remote_src: yes
  tags: kubernetes

- name: Install Flannel CNI
  command: >
    kubectl apply -f {{ flannel_manifest_url }}
  environment:
    KUBECONFIG: /home/ansible/.kube/config
  when: kubeadm_init.changed
  tags: kubernetes

- name: Generate join command
  command: kubeadm token create --print-join-command
  register: join_command
  when: kubeadm_init.changed
  tags: kubernetes

- name: Save join command
  copy:
    content: "{{ join_command.stdout }}"
    dest: /home/ansible/k8s-join-command.sh
    owner: ansible
    group: ansible
    mode: '0600'
  when: join_command.changed
  tags: kubernetes
EOF

# Create k8s-master/handlers/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/handlers/main.yml"
---
- name: Restart containerd
  systemd:
    name: containerd
    state: restarted
  listen: restart_containerd

- name: Apply sysctl
  command: sysctl --system
  listen: apply_sysctl
EOF

# Create k8s-master/templates/containerd-config.toml.j2
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/templates/containerd-config.toml.j2"
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "{{ containerd_sandbox_image }}"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
EOF

# Create k8s-master/templates/kubernetes-sysctl.conf.j2
cat << 'EOF' > "$BASE_DIR/roles/k8s-master/templates/kubernetes-sysctl.conf.j2"
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Create k8s-worker/defaults/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/defaults/main.yml"
---
# Default Kubernetes settings
kubernetes_version: "1.29"
k8s_master_ip: "192.168.0.180"
pod_network_cidr: "10.244.0.0/16"
containerd_sandbox_image: "registry.k8s.io/pause:3.8"
EOF

# Create k8s-worker/vars/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/vars/main.yml"
---
# Role-specific constants
kubernetes_apt_key_url: "https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/Release.key"
kubernetes_apt_repo: "deb https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/ /"
EOF

# Create k8s-worker/tasks/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/tasks/main.yml"
---
# Configure Kubernetes worker node
- name: Include common role for shared setup
  include_role:
    name: common
  tags: [packages, security, vagrant_removal]

- name: Configure Kubernetes worker
  include_tasks: kubernetes.yml
  tags: kubernetes
EOF

# Create k8s-worker/tasks/kubernetes.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/tasks/kubernetes.yml"
---
# Configure Kubernetes worker node with kubeadm
- name: Install dependencies
  apt:
    name:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
    state: present
  tags: kubernetes

- name: Install containerd
  apt:
    name: containerd
    state: present
  tags: kubernetes

- name: Ensure containerd configuration directory exists
  file:
    path: /etc/containerd
    state: directory
    mode: '0755'
  tags: kubernetes

- name: Configure containerd
  template:
    src: containerd-config.toml.j2
    dest: /etc/containerd/config.toml
    mode: '0644'
  notify: restart_containerd
  tags: kubernetes

- name: Enable and start containerd
  systemd:
    name: containerd
    enabled: yes
    state: started
  tags: kubernetes

- name: Add Kubernetes apt key
  apt_key:
    url: "{{ kubernetes_apt_key_url }}"
    state: present
  tags: kubernetes

- name: Add Kubernetes apt repository
  apt_repository:
    repo: "{{ kubernetes_apt_repo }}"
    state: present
    filename: kubernetes
  tags: kubernetes

- name: Install Kubernetes components
  apt:
    name:
      - kubeadm={{ kubernetes_version }}.*
      - kubelet={{ kubernetes_version }}.*
      - kubectl={{ kubernetes_version }}.*
    state: present
    update_cache: yes
  tags: kubernetes

- name: Hold Kubernetes packages
  dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubeadm
    - kubelet
    - kubectl
  tags: kubernetes

- name: Disable swap
  command: swapoff -a
  when: ansible_swaptotal_mb > 0
  changed_when: ansible_swaptotal_mb > 0
  tags: kubernetes

- name: Remove swap from /etc/fstab
  lineinfile:
    path: /etc/fstab
    regexp: '^.*\sswap\s'
    state: absent
  tags: kubernetes

- name: Load kernel modules
  modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - overlay
    - br_netfilter
  tags: kubernetes

- name: Persist kernel modules
  copy:
    content: |
      overlay
      br_netfilter
    dest: /etc/modules-load.d/containerd.conf
    mode: '0644'
  tags: kubernetes

- name: Configure sysctl for Kubernetes
  template:
    src: kubernetes-sysctl.conf.j2
    dest: /etc/sysctl.d/99-kubernetes.conf
    mode: '0644'
  tags: kubernetes

- name: Apply sysctl settings
  command: sysctl --system
  changed_when: true
  tags: kubernetes

- name: Join Kubernetes cluster
  command: /bin/bash /tmp/k8s-join-command.sh
  args:
    creates: /etc/kubernetes/kubelet.conf
  tags: kubernetes
EOF

# Create k8s-worker/handlers/main.yml
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/handlers/main.yml"
---
- name: Restart containerd
  systemd:
    name: containerd
    state: restarted
  listen: restart_containerd

- name: Apply sysctl
  command: sysctl --system
  listen: apply_sysctl
EOF

# Create k8s-worker/templates/containerd-config.toml.j2
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/templates/containerd-config.toml.j2"
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "{{ containerd_sandbox_image }}"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
EOF

# Create k8s-worker/templates/kubernetes-sysctl.conf.j2
cat << 'EOF' > "$BASE_DIR/roles/k8s-worker/templates/kubernetes-sysctl.conf.j2"
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Set permissions
chmod +x "$BASE_DIR/create_ansible_files.sh"

echo "Ansible files created/updated in $BASE_DIR"