### Source code of paper [*Machine Learning for Load Balancing in the Linux Kernel*](https://doi.org/10.1145/3409963.3410492)

Prerequisites:

- [BCC](https://github.com/iovisor/bcc)
- [Tensorflow](https://www.tensorflow.org/)


Dump load balance data:
``` bash
sudo ./dump_lb.py -t tag --old
```
> use `--old` with original kernel without test flag


Automated training and evaluation:
```bash 
cd training
./automate.py -t tag1 tag2 tag3... -o model_name
```

Preprocessing: `training/prep.py`

Training: `training/keras_lb.py`


---
MLLB复现记录

### 一. 基本运行环境
```text
CPU: 13th Gen Intel i5-1335U (12) @ 4.600GHz
OS: Ubuntu 24.04.3 LTS x86_64
Kernel: 6.14.0-33-generic
Memory: 31731MiB
Shell: fish 3.7.0
```

### 二. 安装qemu
```bash
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager

# 添加本用户到KVM组
sudo adduser $USER kvm

# 重启
sudo reboot
```

### 三. 安装 ubuntu 18.04 Server
1. 下载[操作系统镜像](https://releases.ubuntu.com/18.04/).
2. 创建虚拟磁盘.
```bash
qemu-img create -f qcow2 ubuntu1804.qcow2 50G   
```
大小不能少于50G,否则无法提供足够空间编译作者提供的修改内核.
3. 