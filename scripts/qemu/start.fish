#!/usr/bin/fish

set VM_DISK "./ubuntu1804.qcow2"

# 虚拟机硬件配置
set MEMORY_TOTAL "8G"
set MEMORY_NODE0 "4G"
set MEMORY_NODE1 "4G"
set VCPUS 56
set CORES 14
set THREADS 2
set SOCKETS 2

# 启动命令
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host,hv_relaxed,hv_time,hv_vapic,hv_spinlocks=0x1fff \
    -m $MEMORY_TOTAL \
    -smp $VCPUS,cores=$CORES,threads=$THREADS,sockets=$SOCKETS \
    -hda $VM_DISK \
    -name "Ubuntu 1804 Server VM" \
    -netdev user,id=net0,hostfwd=tcp::10023-:22 \
    -device e1000,netdev=net0,mac=52:54:00:12:34:56 \
    -object memory-backend-ram,size=$MEMORY_NODE0,id=mem1 \
    -object memory-backend-ram,size=$MEMORY_NODE1,id=mem2 \
    -numa node,nodeid=0,cpus=0-27,memdev=mem1 \
    -numa node,nodeid=1,cpus=28-55,memdev=mem2

