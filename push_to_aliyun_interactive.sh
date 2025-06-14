#!/bin/bash

read -p "请输入阿里云 Registry 地址（如 registry.cn-hangzhou.aliyuncs.com）: " ALIYUN_REGISTRY
read -p "请输入阿里云命名空间（namespace）: " ALIYUN_NAMESPACE
read -p "请输入阿里云镜像仓库名（repository）: " ALIYUN_REPO
read -p "请输入本地镜像名（如 host-monitor:latest）: " LOCAL_IMAGE
read -p "请输入阿里云用户名（AccessKeyID）: " ALIYUN_USERNAME
read -s -p "请输入阿里云密码（AccessKeySecret）: " ALIYUN_PASSWORD
echo

REMOTE_IMAGE="${ALIYUN_REGISTRY}/${ALIYUN_NAMESPACE}/${ALIYUN_REPO}:latest"

echo "开始登录阿里云容器镜像服务..."
docker login --username=$ALIYUN_USERNAME --password=$ALIYUN_PASSWORD $ALIYUN_REGISTRY
if [ $? -ne 0 ]; then
  echo "❌ 登录失败，请检查用户名和密码"
  exit 1
fi

echo "给本地镜像打标签：$LOCAL_IMAGE -> $REMOTE_IMAGE"
docker tag $LOCAL_IMAGE $REMOTE_IMAGE
if [ $? -ne 0 ]; then
  echo "❌ 镜像打标签失败"
  exit 1
fi

echo "开始推送镜像到阿里云..."
docker push $REMOTE_IMAGE
if [ $? -ne 0 ]; then
  echo "❌ 镜像推送失败"
  exit 1
fi

echo "🎉 镜像推送成功，镜像地址为：$REMOTE_IMAGE"

