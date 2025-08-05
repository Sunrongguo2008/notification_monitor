# 通知监听器与托盘图标闪烁工具

## 介绍

这是一个基于Linux的系统通知监听工具，专门用于监听指定应用程序的通知并在系统托盘中显示闪烁提醒。当检测到来自QQ或Thunderbird的通知时，会在KDE任务栏显示白/黑图标并交替闪烁，同时播放提示音，直到用户单击图标或手动停止。

## 具体功能

### 核心功能
- **通知监听**: 实时监听D-Bus通知接口
- **图标闪烁**: 检测到指定通知时，托盘图标在白/黑之间无限闪烁
- **声音提醒**: 播放系统提示音
- **状态控制**: 支持暂停/启用监听、停止闪烁等操作

### 用户界面功能
- **单击停止**: 单击托盘图标可立即停止闪烁
- **右键菜单**: 提供完整的控制选项
  - 测试闪烁：手动测试图标闪烁效果
  - 停止闪烁：停止当前的闪烁动画
  - 启用监听：复选框控制通知监听状态
  - 重启监听：重新启动通知监听进程
  - 打开程序位置：在文件管理器中打开程序目录
  - 退出：完全退出程序

## 配置说明（均可定制，见”自定义配置“栏目）

### 匹配的应用程序通知
默认监听以下应用程序的通知：
- **QQ**: 腾讯QQ即时通讯软件
- **Thunderbird**: Mozilla Thunderbird邮件客户端

如需添加其他应用程序，请修改脚本中的正则表达式：
```bash
# 在 start_notification_monitor 函数中修改：
grep --line-buffered -E '^\s*string "(QQ|Thunderbird|其他应用名)"$'
```

### 图标文件位置
程序运行时会**自动生成**以下图标文件：
- **位置**: `~/notification_monitor/`
- **文件名**: 
  - `icon_a.svg`: 白色圆形图标
  - `icon_b.svg`: 黑色圆形图标

### 声音文件配置
默认使用系统提示音：
- **文件路径**: `/usr/share/sounds/freedesktop/stereo/message.oga`
- **可自定义**: 修改脚本中的 `VOICE_FILE` 变量

## 安装与使用

### 系统要求
- Arch Linux 或其他支持的Linux发行版
- KDE桌面环境（推荐）或其他支持系统托盘的桌面环境
- Python 3.6+
- PyQt5

### 安装依赖
```bash
# Arch Linux
sudo pacman -S python-pyqt5

# 或使用pip
pip install PyQt5
```

### 安装步骤
1. 克隆仓库：
```bash
git clone https://github.com/Sunrongguo2008/notification_monitor
cd notification_monitor
```
⚠️`notification_monitor.sh`的文件名是写死在脚本里的，不要改名。想要改名，记得把脚本里的`notification_monitor`部分也替换了。

2. 添加执行权限：
```bash
chmod +x ~/notification_monitor/notification_monitor.sh
```

3. 运行程序：
```bash
cd ~/notification_monitor
./notification_monitor.sh
```

## 使用方法

### 启动程序
```bash
cd ~/notification_monitor
./notification_monitor.sh
```

### 控制操作
- **单击托盘图标**: 停止当前闪烁
- **右键托盘图标**: 打开控制菜单
  - ✓ 启用监听：勾选表示监听已启用，取消勾选表示禁用
  - 测试闪烁：手动触发闪烁测试
  - 停止闪烁：强制停止闪烁动画
  - 重启监听：重新启动监听进程
  - 打开程序位置：在文件管理器中打开程序目录
  - 退出：完全退出程序

## 文件结构

```
~/notification_monitor/
├── notification_monitor.sh    # 主程序脚本
├── icon_a.svg                 # 白图标文件（嵌入、自动生成）
├── icon_b.svg                 # 黑图标文件（嵌入、自动生成）
├── tray_icon.py              # Python托盘图标程序（嵌入、自动生成）
├── control.status            # 监听控制状态文件（运行时生成）
└── monitor.pid               # 监听进程PID文件（运行时生成）
```

## 故障排除

### 常见问题
1. **托盘图标不显示**:
   - 确认桌面环境支持系统托盘
   - 检查KDE系统托盘设置是否启用
   - 重启程序

2. **图标不闪烁**:
   - 检查 `/tmp/notification_alert` 文件是否被创建
   - 确认监听状态已启用
   - 查看终端输出日志

3. **声音不播放**:
   - 确认 `paplay` 命令可用
   - 检查音频设备是否正常工作
   - 验证声音文件路径是否存在

### 调试命令
```bash
# 手动测试闪烁
touch /tmp/notification_alert

# 检查程序运行状态
ps aux | grep notification_monitor

# 查看控制状态
cat ~/notification_monitor/control.status
```

## 自定义配置

### 修改监听应用
编辑脚本中的正则表达式部分：
```bash
# 原始配置
grep --line-buffered -E '^\s*string "(QQ|Thunderbird)"$'

# 添加微信示例
grep --line-buffered -E '^\s*string "(QQ|Thunderbird|WeChat)"$'
```

### 修改托盘图标
⚠️不要修改`tray_icon.py`！`notification_monitor.sh`每次启动会自动覆盖`tray_icon.py`的内容。应直接修改`notification_monitor.sh`。
在脚本中修改：
```bash
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
```

### 修改闪烁间隔
⚠️不要修改`tray_icon.py`！`notification_monitor.sh`每次启动会自动覆盖`tray_icon.py`的内容。应直接修改`notification_monitor.sh`。
在脚本中修改：
```bash
self.blink_timer.start(500)  # 500ms = 0.5秒
```

### 修改声音文件
修改脚本顶部的 `VOICE_FILE` 变量：
```bash
VOICE_FILE="/path/to/your/sound/file.ogg"
```

## 开机自启动

### 方法一：使用KDE自动启动
1. 打开"系统设置" → "开机和关机" → "自动启动"
2. 点击"添加脚本"
3. 选择 `~/notification_monitor/notification_monitor.sh`

### 方法二：使用systemd用户服务
创建服务文件：
```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/notification-monitor.service << EOF
[Unit]
Description=Notification Monitor with Tray Icon
After=graphical-session.target

[Service]
Type=simple
ExecStart=/home/$(whoami)/notification_monitor/notification_monitor.sh
Restart=always
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF
```

启用服务：
```bash
systemctl --user daemon-reload
systemctl --user enable notification-monitor.service
systemctl --user start notification-monitor.service
```

## 许可证

本项目为开源软件，使用**Apache License 2.0**许可。可根据需要自由使用、修改和分发。


## 支持与反馈

如有问题或建议，请提交issue或联系开发者。
