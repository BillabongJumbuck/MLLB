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

### 一. 运行环境

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
3. 在虚拟磁盘安装操作系统 [create.fish](./scripts/qemu/create.fish)

```shell
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
```

4. 配置qemu虚拟机网络和硬件选项 [start.fish](./scripts/qemu/start.fish)

   ```shell
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
   
   # 将虚拟机22号端口转发至宿主机10023号端口,从而可以使用SSH登陆虚拟机操作系统
   
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
   ```



### 四. 配置虚拟机代码运行环境

**以下所有操作在虚拟机进行**

0. 安装pip

```shell
sudo apt install python3-pip
```

1. 安装BCC

   收集数据的代码使用BCC工具。最低版本要求为v0.10.0. 低于此版本将无法运行作者提供的收集数据代码.
   
   **通过apt install从软件仓库安装的bcc版本为v0.5.0,无法运行作者的代码!**
   
   **因此, 改用从源代码编译的方式安装.**

```shell
# 安装编译工具
sudo apt install -y \
  zip bison build-essential cmake flex git libedit-dev \
  llvm-6.0 llvm-6.0-dev libclang-6.0-dev python3-setuptools \
  zlib1g-dev libelf-dev liblzma-dev arping netperf iperf
  
# clone源代码
git clone https://github.com/iovisor/bcc.git
cd bcc
git checkout v0.10.0  # 切换为0.10.0版本
mkdir build 
cd build
cmake ..      # 可能会提示需要更高版本的cmake,参见 #升级cmake
make

# build python3 binding
cmake -DPYTHON_CMD=python3 .. 
pushd src/python/
make
sudo make install
popd

# 安装python3软件包
cd src/python/bcc-python3
sudo -H pip3 install .
pip3 list | grep bcc  # 验证bcc安装版本

# 加载libbcc动态链接库
# 回到bcc/build目录
cd src/cc
sudo make install
sudo ldconfig
ldconfig -p | grep libbcc  # 验证安装
```

> ##### 	升级cmake (直接下载 CMake 二进制包)
> 
> ```shell
> cd /tmp
> wget https://github.com/Kitware/CMake/releases/download/v3.27.0/cmake-3.27.0-linux-x86_64.tar.gz
> tar xf cmake-3.27.0-linux-x86_64.tar.gz
> sudo mv cmake-3.27.0-linux-x86_64 /opt/cmake
> sudo ln -sf /opt/cmake/bin/* /usr/local/bin/
> cmake --version # 验证版本
> ```

2. 安装tensorflow

   ubuntu 18.04 server自带的python版本为3.6.9. 针对该版本进行tensorflow的安装.

```shell 
pip3 install tensorflow==1.14.0
```

>  可能出现的问题: tensorflow依赖protobuf, 最新的protobuf已放弃对python3.6.9的支持.
>
>  ```shell
>  protobuf requires Python '>=3.7' but the running Python is 3.6.9
>  ```
>
>  解决方法
>
>  ```shell
>  pip3 install protobuf==3.18.0  # 手动安装低版本protobuf
>  pip3 install tensorflow==1.14.0 --no-deps # 禁用自动安装依赖
>  # 手动安装其他依赖
>  pip3 install numpy absl-py wrapt gast astor termcolor keras_applications keras_preprocessing
>  ```



### 五. 收集数据

1. 克隆作者仓库

```shell
git clone https://github.com/Keitokuch/MLLB.git
```

2. 安装工作负载模拟工具

```shell
sudo apt install stress-ng
```

3. 运行数据收集脚本

```shell
pip3 install pandas
sudo ./dump_lb.py -t tag --old -o raw_tag1.csv # 原生内核必须使用--old参数
```

4. 模拟工作负载

```shell
# 强制 Node 0 上的 CPU 访问 Node 1 的内存，模拟最差的 NUMA 性能
stress-ng --numa 1 --numa-method malloc_rand --numa-cpu 0-27 --numa-dom 1 --timeout 60s
# 使一个 NUMA 节点达到极限，但保持另一个节点完全空闲
stress-ng --cpu 28 --cpu-method matrixprod --cpu-affinity 0-27 --timeout 60s
# 模拟多个进程频繁竞争 L1/L2/L3 缓存的情况
stress-ng --cache 56 --cache-level 3 --cache-ops 1000000 --timeout 60s
# 在 56 个 VCPU 上创建远超 VCPU 数量的进程，迫使内核调度器频繁地进行上下文切换
stress-ng --cpu 112 --timeout 60s
# 模拟数据库或文件系统元数据操作等需要大量随机读写的场景
stress-ng --hdd 56 --hdd-method seek --hdd-bytes 10G --timeout 60s
# 矩阵乘法压力测试
stress-ng --cpu 32 --cpu-method matrixprod --matrix-size 512 --timeout 60s
# 快速傅里叶变换压力测试
stress-ng --cpu 48 --cpu-method fft --timeout 60s
# 混合负载模式
stress-ng --cpu 10 --vm 2 --vm-bytes 1G --hdd 1 --timeout 90s
```

5. 查看收集到的数据

```shell
cat raw_tag1.csv | head -n 100  # 查看前100行
wc -l raw_tag1.csv  # 统计数据量
```



### 六. 训练

​	自动化训练

```shell
cd training
./automate.py -t tag1 -o model_name -d
```
> 训练结束后拍,在training文件夹下新增五个文件
> model_model_name.h5        post_model_name.csv     weights_model_name.h5
> pickle_model_name.weights  predict_model_name.csv

​	查看MLP各层权重和偏置

```shell
python3 dump_weights.py model_0001
```

> 共输出18行171个参数
>
> W1: 1-15行	b1: 16行	W2:  17行	b2:  18行



### 七. 编译内核

​	在作者开源的修改内核中, 作者提供了一些编译选项, 来决定ML负载均衡方法的运作方式.具体包括:

- ##### **CONFIG_JC_SCHED**

  这是ML负载实现的总开关. 当该选项为y时,表示开启ML负载均衡;否则表示关闭ML负载均衡.下面所有选项仅当CONFIG_JC_SCHED=y时有效.

- ##### **CONFIG_JC_SCHED_TOGGLE**, **CONFIG_JC_SCHED_REPLACE**, CONFIG_JC_SCHED_TEST

  - 三个选项是互斥的,代表了ML负载均衡运行的三种模式
  - CONFIG_JC_SCHED_REPLACE模式表示由ML方法取代CFS方法,完全由ML进行负载均衡决策.
  - CONFIG_JC_SCHED_TEST模式将ML决策与CFS决策并行运行,并打印到日志.用于模型精确度评估.
  - CONFIG_JC_SCHED_TOGGLE模式表示运行时切换,允许通过系统调用来表示使用ML还是CFS进行负载均衡决策

- **CONFIG_JC_SCHED_FXDPT**

  - 等于y时表示使用定点数进行运算. 否则使用浮点数

- **CONFIG_JC_SCHED_PERF**

  - 等于y时表示启用硬件数据采集

​	推荐编译选项配置:

```shell
#
# Sched Experiment
#
CONFIG_JC_SCHED=y
# CONFIG_JC_SCHED_TOGGLE is not set
# CONFIG_JC_SCHED_REPLACE is not set
CONFIG_JC_SCHED_TEST=y
CONFIG_JC_SCHED_FXDPT=y
CONFIG_JC_SCHED_PERF=y
```

​	完整的.config文件可参考[scripts/.config](scripts/.config)

​	接下来编译和安装作者的修改内核.

1. 克隆源代码

```shell
git clone https://github.com/Keitokuch/linux-4.15-lb.git
```
2. 配置编译选项
```shell
# 将.config文件拷贝到该目录下或使用以下命令自定义编译选项
# 把当前运行的内核配置拷贝到源代码目录
cp -v /boot/config-$(uname -r) .config  # 使用bash 或
cp -v /boot/config-(uname -r) .config  # 使用fish
# 基于旧的配置（.config），用新内核版本的默认值来填充所有新增的配置选项
make olddefconfig
# 自定义配置
make menuconfig
```
3. 编译
``` shell
make -j$(nproc)  # 使用bash 或
make -j(nproc)  # 使用fish
```

>  第一次编译持续时间较长. 在我的机器上大约共花费1个小时. 具体依机器性能而定.
>
> 编译过程需要大量的磁盘空间, 若系统`/`分区分配的磁盘空间过小(一般来说, 小于25G), 会因磁盘空间不足而中断编译. 需要为`/`分区分配更多磁盘空间, 在重新运行`make -j(nproc)`继续编译.
>
> 注意, 即使qemu-img创建的磁盘大于25G, 仍可能产生磁盘空间不足问题, 因为文件系统可能没有完全使用磁盘空间.可以通过下面的命令为文件系统分配更多的空间.
>
> ```shell
> sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
> sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
> ```
>
> 

4. 安装

```shell
sudo make modules_install  # 安装编译好的内核模块（如驱动程序）到 /lib/modules/ 目录
sudo make install # 安装内核镜像（vmlinuz-*）和更新启动加载器配置（例如GRUB）
```

5. 启动新内核

   i. 重启

   ii. 在启动界面,进入GRUB菜单, 选择"Advanced options for Ubunutu",

   iii. 选择新内核版本启动, 名称后缀为4.15.0+

   iv. 成功启动后, 可通过``uname -r`验证是否启动了新版本



### 八. 测试

**测试部分仅针对开启了CONFIG_JC_SCHED_TEST编译选项的定制内核**

1. 开启测试

   ​	作者定义了一个名为 jc_sched 的系统调用，接受一个整型参数 start. 当start非零时, 系统在每次触发负载均衡决策时, 会将CFS和ML的决策结果同时打印到日志中, 从而对比ML决策的准确率.当start为0时, 停止打印日志.

   ​	由于作者未提供调用该系统调用的代码, 因此使用[如下](scripts/syscall/enable_jc_sched.c)C语言程序开启/关闭日志打印.

   ```C
   #include <stdio.h>
   #include <unistd.h>
   #include <stdlib.h>
   #include <sys/syscall.h>
   
   // 根据内核代码，系统调用号是 345
   #define __NR_jc_sched 345 
   
   int main(int argc, char *argv[]) {
       long ret;
       int start = 0;
   
       if (argc < 2) {
           printf("用法: %s <0 或 1>\n", argv[0]);
           printf("参数 1 开启 ML 调度和日志；参数 0 关闭。\n");
           return 1;
       }
       
       start = atoi(argv[1]);
   
       // 调用系统调用
       ret = syscall(__NR_jc_sched, start); 
   
       if (ret == 0) {
           printf("ML Sched (jc_sched) %s 成功。\n", start ? "开启" : "关闭");
       } else {
           perror("syscall jc_sched 失败");
       }
   
       return 0;
   }
   
   ```

   编译和使用:

   ```shell
   gcc -o jc_sched_ctl enable_jc_sched.c # 编译C程序
   
   sudo ./jc_sched_ctl 1  # 开启日志打印
   sudo ./jc_sched_ctl 0  # 关闭日志打印
   ```

2.  运行stress-ng 负载模拟程序

3. 在MLLB/eval文件夹下, 运行测试结果统计脚本

   ```shell
   python3 eval_acc.py  # 测试准确率
   python3 eval_time.py  # 测试时间耗费
   ```

