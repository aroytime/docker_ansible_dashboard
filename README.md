# docker_ansible_dashboard
docker部署数据大屏期末作业
# About 本项目

本项目基于 **Flask** 框架开发，结合 **Ansible** 和 **Docker** 实现了一个简单易用的主机状态监控与管理平台。
用户可以通过前端界面，方便地进行主机信息的添加、删除、修改与查询操作。

### 主要功能

* 基于 Web 的主机管理界面，支持动态增删改查
* 自动检测并修复 Docker 网络冲突，保障容器网络稳定
* 支持批量 SSH 密钥分发与配置，简化远程管理
* 镜像上传至阿里云容器镜像仓库，方便云端部署

### 技术栈

* 后端：Python3 + Flask + Ansible
* 前端：HTML + CSS + JavaScript
* 容器：Docker + Shell 脚本自动化管理
