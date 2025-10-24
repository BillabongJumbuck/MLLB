#!/usr/bin/fish

qemu-system-x86_64 \
    -enable-kvm \
    -name "Ubuntu 1804 Server VM" \
    -m 8192 \
    -cpu host \
    -smp cores=4,threads=1,sockets=1 \
    -vga virtio \
    -display gtk \
    -nic user,model=virtio-net-pci \
    -hda ubuntu1804.qcow2 \
    -cdrom ./ubuntu-18.04.6-live-server-amd64.iso \
    -boot d
