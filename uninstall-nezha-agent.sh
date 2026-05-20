#!/bin/sh
# 哪吒探针 Agent 通用卸载脚本
# 支持 Debian (systemd) 和 Alpine (OpenRC)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
    else
        OS="debian"
    fi
    echo -e "${GREEN}检测到系统: $OS${NC}"
}

# 停止服务（兼容 systemd 和 OpenRC）
stop_service() {
    echo -e "${YELLOW}正在停止 nezha-agent 服务...${NC}"
    
    # 尝试 systemd
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop nezha-agent 2>/dev/null || true
        systemctl disable nezha-agent 2>/dev/null || true
        echo "已停止 systemd 服务"
    fi
    
    # 尝试 OpenRC (Alpine)
    if [ -f /etc/init.d/nezha-agent ]; then
        rc-service nezha-agent stop 2>/dev/null || true
        rc-update del nezha-agent default 2>/dev/null || true
        echo "已停止 OpenRC 服务"
    fi
}

# 杀掉残留进程
kill_processes() {
    echo -e "${YELLOW}正在清理残留进程...${NC}"
    
    # 杀掉所有 nezha-agent 进程
    pkill -9 nezha-agent 2>/dev/null || true
    killall -9 nezha-agent 2>/dev/null || true
    
    # 使用 ps 备用方案
    ps aux | grep -E 'nezha-agent' | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    
    echo "进程已清理"
}

# 删除服务文件
remove_service_files() {
    echo -e "${YELLOW}正在删除服务文件...${NC}"
    
    # systemd 文件
    rm -f /etc/systemd/system/nezha-agent.service
    rm -f /etc/systemd/system/multi-user.target.wants/nezha-agent.service
    rm -rf /etc/systemd/system/nezha-agent.service.d
    
    # OpenRC 文件 (Alpine)
    rm -f /etc/init.d/nezha-agent
    rm -f /etc/runlevels/default/nezha-agent
    
    # 其他配置文件
    rm -f /etc/default/nezha-agent
    rm -f /etc/conf.d/nezha-agent
    
    echo "服务文件已删除"
}

# 删除程序文件
remove_program_files() {
    echo -e "${YELLOW}正在删除程序文件...${NC}"
    
    # 删除主目录
    rm -rf /opt/nezha/agent/
    rm -rf /opt/nezha-agent/
    rm -rf /usr/local/nezha-agent/
    
    # 查找并删除可能的安装位置
    find / -name "nezha-agent" -type f 2>/dev/null | grep -v "/proc/" | xargs rm -f 2>/dev/null || true
    
    echo "程序文件已删除"
}

# 删除日志文件
remove_logs() {
    echo -e "${YELLOW}正在删除日志文件...${NC}"
    
    rm -f /var/log/nezha-agent.log
    rm -f /var/log/nezha-agent/*.log
    rm -f /opt/nezha/agent/*.log
    rm -rf /var/log/nezha-agent/
    
    echo "日志文件已删除"
}

# 重载服务管理器
reload_services() {
    echo -e "${YELLOW}正在重载服务管理器...${NC}"
    
    # systemd
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload 2>/dev/null || true
    fi
    
    # OpenRC
    if command -v rc-service >/dev/null 2>&1; then
        rc-service -s 2>/dev/null || true
    fi
    
    echo "服务管理器已重载"
}

# 验证清理结果
verify_cleanup() {
    echo -e "${YELLOW}正在验证清理结果...${NC}"
    
    # 检查进程
    if ps aux | grep -E 'nezha-agent' | grep -v grep > /dev/null; then
        echo -e "${RED}⚠️ 仍有残留进程:${NC}"
        ps aux | grep -E 'nezha-agent' | grep -v grep
    else
        echo -e "${GREEN}✅ 进程已清理干净${NC}"
    fi
    
    # 检查服务
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl status nezha-agent 2>&1 | grep -q "could not find\|not found\|No such file"; then
            echo -e "${GREEN}✅ 服务文件已清理${NC}"
        else
            echo -e "${RED}⚠️ 服务文件可能未完全清理${NC}"
        fi
    fi
    
    # 检查文件
    if [ -d /opt/nezha/agent ] || [ -f /usr/local/bin/nezha-agent ]; then
        echo -e "${RED}⚠️ 仍有残留文件${NC}"
    else
        echo -e "${GREEN}✅ 文件已清理干净${NC}"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}哪吒探针 Agent 通用卸载脚本${NC}"
    echo -e "${GREEN}================================${NC}"
    
    # 确认卸载
    echo -e "${YELLOW}即将彻底删除哪吒 Agent，包括：${NC}"
    echo "  - 所有 nezha-agent 进程"
    echo "  - systemd/OpenRC 服务文件"
    echo "  - 程序文件 (/opt/nezha/agent)"
    echo "  - 日志文件"
    echo ""
    printf "确认删除？(y/N): "
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${RED}已取消卸载${NC}"
        exit 0
    fi
    
    # 执行清理
    detect_os
    stop_service
    kill_processes
    remove_service_files
    remove_program_files
    remove_logs
    reload_services
    
    echo ""
    verify_cleanup
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}✅ 哪吒 Agent 已彻底删除！${NC}"
    echo -e "${GREEN}================================${NC}"
}

# 运行主函数
main
