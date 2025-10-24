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