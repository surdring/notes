# 下载 Chrome .deb 包
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# 安装
sudo dpkg -i google-chrome-stable_current_amd64.deb

# 如果有依赖问题，运行：
sudo apt-get install -f