#!/bin/bash
# 单文件通知监听和托盘图标管理器

# 获取当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "脚本目录: $SCRIPT_DIR"

# 设置文件路径
ICON_A="$SCRIPT_DIR/icon_a.svg"
ICON_B="$SCRIPT_DIR/icon_b.svg"
VOICE_FILE="/usr/share/sounds/freedesktop/stereo/message.oga"
PID_FILE="$SCRIPT_DIR/monitor.pid"
CONTROL_FILE="$SCRIPT_DIR/control.status"  # 控制状态文件

# 初始化控制文件 - 默认启用监听
echo "enabled" > "$CONTROL_FILE"  # enabled | disabled

# 清理之前的临时文件
rm -f /tmp/notification_alert

# 创建图标文件
cat > "$ICON_A" << 'EOF'
<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="white" />
</svg>
EOF

cat > "$ICON_B" << 'EOF'
<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="black" />
</svg>
EOF

# 创建嵌入的Python脚本
cat > "$SCRIPT_DIR/tray_icon.py" << PYTHON_SCRIPT
#!/usr/bin/env python3
import sys
import os
import time
import subprocess
from PyQt5.QtWidgets import QSystemTrayIcon, QApplication, QMenu, QAction
from PyQt5.QtGui import QIcon
from PyQt5.QtCore import QTimer
import signal

class NotificationTrayIcon(QSystemTrayIcon):
    def __init__(self, icon_a_path, icon_b_path, script_dir):
        super().__init__()

        self.script_dir = script_dir
        self.icon_a = QIcon(icon_a_path)
        self.icon_b = QIcon(icon_b_path)
        self.current_icon = 'A'
        self.is_blinking = False
        self.monitor_enabled = True

        # 设置初始图标
        self.setIcon(self.icon_a)
        self.setToolTip("通知监听器 - 监听已启用")
        print("托盘图标初始化完成")

        # 创建右键菜单
        self.create_menu()

        # 显示托盘图标
        self.show()
        print("托盘图标已显示")

        # 添加单击事件处理
        self.activated.connect(self.on_tray_icon_activated)

        # 创建定时器用于图标闪烁
        self.blink_timer = QTimer()
        self.blink_timer.timeout.connect(self.toggle_icon)

        # 定时检查信号文件和控制状态
        self.check_timer = QTimer()
        self.check_timer.timeout.connect(self.check_status)
        self.check_timer.start(200)  # 每200ms检查一次

    def create_menu(self):
        """创建右键菜单"""
        self.menu = QMenu()

        # 测试闪烁
        self.test_action = QAction("测试闪烁", self.menu)
        self.test_action.triggered.connect(self.test_blink)
        self.menu.addAction(self.test_action)

        # 停止闪烁
        self.stop_blink_action = QAction("停止闪烁", self.menu)
        self.stop_blink_action.triggered.connect(self.stop_blinking)
        self.stop_blink_action.setEnabled(False)
        self.menu.addAction(self.stop_blink_action)

        self.menu.addSeparator()

        # 启用/禁用监听 (使用复选框样式)
        self.toggle_monitor_action = QAction("启用监听", self.menu)
        self.toggle_monitor_action.setCheckable(True)
        self.toggle_monitor_action.setChecked(True)
        self.toggle_monitor_action.triggered.connect(self.toggle_monitor)
        self.menu.addAction(self.toggle_monitor_action)

        # 重启监听
        restart_action = QAction("重启监听", self.menu)
        restart_action.triggered.connect(self.restart_monitor)
        self.menu.addAction(restart_action)

        self.menu.addSeparator()

        # 打开程序位置
        open_location_action = QAction("打开程序位置", self.menu)
        open_location_action.triggered.connect(self.open_location)
        self.menu.addAction(open_location_action)

        self.menu.addSeparator()

        # 退出
        quit_action = QAction("退出", self.menu)
        quit_action.triggered.connect(self.quit_application)
        self.menu.addAction(quit_action)

        self.setContextMenu(self.menu)

    def toggle_icon(self):
        """切换图标"""
        if self.current_icon == 'A':
            self.setIcon(self.icon_b)
            self.current_icon = 'B'
        else:
            self.setIcon(self.icon_a)
            self.current_icon = 'A'

    def start_blinking(self):
        """开始无限图标闪烁"""
        # 检查监听是否启用
        control_file = os.path.join(self.script_dir, "control.status")
        if os.path.exists(control_file):
            try:
                with open(control_file, 'r') as f:
                    status = f.read().strip()
                if status == "disabled":
                    return  # 监听已禁用，不闪烁
            except:
                pass

        if not self.is_blinking:
            print("开始无限闪烁...")
            self.is_blinking = True
            self.blink_timer.start(500)  # 500ms切换一次
            self.stop_blink_action.setEnabled(True)
            self.setToolTip("通知监听器 - 闪烁中...")

    def stop_blinking(self):
        """停止图标闪烁"""
        if self.is_blinking:
            print("停止闪烁")
            self.blink_timer.stop()
            self.is_blinking = False
            self.setIcon(self.icon_a)  # 恢复到A图标
            self.current_icon = 'A'
            self.stop_blink_action.setEnabled(False)
            # 恢复工具提示
            if not self.monitor_enabled:
                self.setToolTip("通知监听器 - 监听已禁用")
            else:
                self.setToolTip("通知监听器 - 监听已启用")

    def check_status(self):
        """检查信号文件和控制状态"""
        # 检查通知信号
        if os.path.exists("/tmp/notification_alert"):
            print("检测到通知信号文件")
            os.remove("/tmp/notification_alert")
            self.start_blinking()

        # 检查控制状态文件
        control_file = os.path.join(self.script_dir, "control.status")
        if os.path.exists(control_file):
            try:
                with open(control_file, 'r') as f:
                    status = f.read().strip()

                if status == "disabled" and self.monitor_enabled:
                    self.monitor_enabled = False
                    self.toggle_monitor_action.setChecked(False)
                    # 停止闪烁
                    if self.is_blinking:
                        self.stop_blinking()
                    self.setToolTip("通知监听器 - 监听已禁用")
                    print("监听已禁用")
                elif status == "enabled" and not self.monitor_enabled:
                    self.monitor_enabled = True
                    self.toggle_monitor_action.setChecked(True)
                    self.setToolTip("通知监听器 - 监听已启用")
                    print("监听已启用")
            except Exception as e:
                print(f"读取控制文件出错: {e}")

    def test_blink(self):
        """测试闪烁功能"""
        print("测试闪烁功能")
        self.start_blinking()

    def toggle_monitor(self):
        """切换监听状态"""
        control_file = os.path.join(self.script_dir, "control.status")
        try:
            # 获取当前选中状态
            is_checked = self.toggle_monitor_action.isChecked()

            if is_checked:
                # 启用监听
                with open(control_file, 'w') as f:
                    f.write("enabled")
                self.monitor_enabled = True
                self.setToolTip("通知监听器 - 监听已启用")
                print("监听已启用")
            else:
                # 禁用监听
                with open(control_file, 'w') as f:
                    f.write("disabled")
                self.monitor_enabled = False
                # 停止闪烁
                if self.is_blinking:
                    self.stop_blinking()
                self.setToolTip("通知监听器 - 监听已禁用")
                print("监听已禁用")
        except Exception as e:
            print(f"切换监听状态出错: {e}")

    def restart_monitor(self):
        """重启监听进程"""
        script_path = os.path.join(self.script_dir, "notification_monitor.sh")
        subprocess.Popen([script_path])
        # 重置控制状态
        control_file = os.path.join(self.script_dir, "control.status")
        with open(control_file, 'w') as f:
            f.write("enabled")
        self.monitor_enabled = True
        self.toggle_monitor_action.setChecked(True)
        # 停止当前闪烁
        if self.is_blinking:
            self.stop_blinking()
        self.setToolTip("通知监听器 - 已重启")
        print("监听器已重启")

    def open_location(self):
        """打开程序位置"""
        try:
            # 尝试使用xdg-open
            subprocess.Popen(['xdg-open', self.script_dir])
        except Exception as e:
            print(f"打开文件管理器失败: {e}")
            try:
                # 备用方案：使用dolphin (KDE)
                subprocess.Popen(['dolphin', self.script_dir])
            except:
                try:
                    # 备用方案：使用nautilus (GNOME)
                    subprocess.Popen(['nautilus', self.script_dir])
                except:
                    print("无法打开文件管理器")
    def on_tray_icon_activated(self, reason):
        """处理托盘图标激活事件"""
        if reason == QSystemTrayIcon.Trigger:  # 单击左键
            if self.is_blinking:
                self.stop_blinking()

    def quit_application(self):
        """退出应用程序"""
        print("退出应用程序")
        # 停止所有定时器
        self.blink_timer.stop()
        self.check_timer.stop()
        # 清理文件
        control_file = os.path.join(self.script_dir, "control.status")
        if os.path.exists(control_file):
            os.remove(control_file)
        QApplication.quit()

def main():
    # 设置应用程序名称
    QApplication.setApplicationName("NotificationMonitor")

    app = QApplication(sys.argv)

    # 处理信号
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    # 获取参数
    if len(sys.argv) < 4:
        print("使用方法: python3 tray_icon.py <icon_a_path> <icon_b_path> <script_dir>")
        sys.exit(1)

    icon_a_path = sys.argv[1]
    icon_b_path = sys.argv[2]
    script_dir = sys.argv[3]

    print(f"启动托盘图标: A={icon_a_path}, B={icon_b_path}")

    # 创建托盘图标
    tray_icon = NotificationTrayIcon(icon_a_path, icon_b_path, script_dir)

    # 运行事件循环
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

# 函数：启动托盘图标
start_tray_icon() {
    if ! pgrep -f "tray_icon.py" > /dev/null; then
        python3 "$SCRIPT_DIR/tray_icon.py" "$ICON_A" "$ICON_B" "$SCRIPT_DIR" &
        echo "托盘图标已启动 (PID: $!)"
        sleep 1
    else
        echo "托盘图标已在运行"
    fi
}

# 函数：启动通知监听
start_notification_monitor() {
    echo $$ > "$PID_FILE"
    echo "通知监听器启动 (PID: $$)"

    echo "开始监听通知..."
    dbus-monitor 'type=method_call, interface=org.freedesktop.Notifications, member=Notify' | \
    while read -r line; do
        # 检查控制状态 - 修复逻辑
        if [ -f "$CONTROL_FILE" ]; then
            status=$(cat "$CONTROL_FILE" 2>/dev/null)
            if [ "$status" = "disabled" ]; then
                # 监听已禁用，跳过处理
                echo "监听已禁用，跳过通知处理"
                continue
            fi
        fi

        # 检查是否是目标应用的通知
        if echo "$line" | grep -qE '^\s*string "(QQ|Thunderbird)"$'; then
            app_name=$(echo "$line" | sed 's/.*string "\(.*\)".*/\1/')
            echo "[$(date)] 检测到来自 $app_name 的通知"

            # 触发图标闪烁
            touch /tmp/notification_alert
            echo "已创建信号文件 /tmp/notification_alert"

            # 播放声音
            if [ -f "$VOICE_FILE" ]; then
                echo "播放提示音"
                paplay "$VOICE_FILE" 2>/dev/null || echo "无法播放声音文件"
            else
                echo "提示音文件不存在: $VOICE_FILE"
            fi
        fi
    done
}

# 主程序逻辑
case "${1:-}" in
    "--monitor")
        # 启动通知监听模式
        start_notification_monitor
        ;;
    "--tray")
        # 启动托盘图标模式
        start_tray_icon
        ;;
    "--test")
        # 测试模式
        echo "测试图标闪烁..."
        touch /tmp/notification_alert
        sleep 5
        rm -f /tmp/notification_alert
        ;;
    *)
        # 默认行为：启动托盘图标和监听器
        echo "启动通知监听器..."

        # 确保控制文件状态为启用
        echo "enabled" > "$CONTROL_FILE"

        # 启动托盘图标
        start_tray_icon

        # 等待托盘图标启动
        sleep 3

        # 启动通知监听（后台）
        "$SCRIPT_DIR/notification_monitor.sh" --monitor &

        echo "系统已启动，按 Ctrl+C 退出"
        echo "右键点击托盘图标可以控制闪烁和监听状态"

        # 保持主进程运行
        trap "echo '正在退出...'; echo 'disabled' > '$CONTROL_FILE'; rm -f $PID_FILE /tmp/notification_alert; killall python3 2>/dev/null; exit" INT TERM
        while true; do
            sleep 1
        done
        ;;
esac
