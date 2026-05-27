在 Ubuntu 上卸载 Clash Verge，主要取决于你当初是通过哪种方式安装的。以下是几种常见安装方式的对应卸载方法，你可以按照顺序尝试：

### 1. 通过 APT / .deb 包安装（最常见）

如果你是通过下载 `.deb` 安装包或使用 `apt` 命令安装的，可以使用终端命令来彻底卸载：

1. **查找软件包名**：打开终端，输入以下命令确认包名（通常是 `clash-verge`）：
    
    ```bash
    dpkg -l | grep clash
    ```
    
2. **彻底卸载并清理配置**：找到包名后，运行以下命令进行完全卸载（包含配置文件），并自动删除不再需要的依赖项：
    
    ```bash
    sudo apt purge clash-verge
    sudo apt autoremove
    ```
    

### 2. 通过 Snap 安装

如果你是通过 Snap 商店安装的，卸载非常简单：

- 直接在终端中执行：
    
    ```bash
    sudo snap remove clash-verge
    ```
    

### 3. 手动安装或 AppImage（便携版）

如果你是直接下载的压缩包自行解压，或者使用的是 `AppImage` 文件，系统并没有真正“安装”它，只是放了一个启动图标。你需要手动删除文件和快捷方式：

1. **删除程序本体**：找到你当初存放 Clash Verge 的位置（通常在 `~/Downloads`、`~/Apps` 或 `/opt` 目录下），直接删除对应的文件夹或 `.AppImage` 文件。
2. **删除应用菜单的启动图标**：在终端中运行以下命令查找并删除它的 `.desktop` 启动器文件：
    
    ```bash
    find ~/.local/share/applications -name "*clash*.desktop"
    rm ~/.local/share/applications/*clash*.desktop
    ```
    

### 4. 清理残留的配置文件和缓存

无论使用哪种方式卸载，为了达到最干净的效果，建议手动检查并删除用户目录下的相关配置文件夹。在终端中执行：

```bash
rm -rf ~/.config/clash-verge
rm -rf ~/.local/share/clash-verge
```

通常执行完第 1 种或第 2 种方法，再配合第 4 步的残留清理，就能把 Clash Verge 从你的 Ubuntu 系统中彻底移除了。