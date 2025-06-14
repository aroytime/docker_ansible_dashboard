#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}🚀 Docker 自动网络配置开始...${NC}"

# 1. 输入网络名 + 判断是否已存在
while true; do
    read -p "请输入 Docker 网络名称（如 my_bridge_net）: " NET_NAME
    if docker network ls --format '{{.Name}}' | grep -wq "$NET_NAME"; then
        echo -e "${RED}⚠️ 网络名称 [$NET_NAME] 已存在！${NC}"
        read -p "是否删除并重建该网络？(y/n): " confirm_name
        if [[ "$confirm_name" == "y" ]]; then
            docker network rm "$NET_NAME"
            echo -e "${GREEN}✅ 旧网络已删除，可以继续使用该名称。${NC}"
            break
        else
            echo -e "${YELLOW}请重新输入其他网络名称。${NC}"
        fi
    else
        echo -e "${GREEN}✅ 网络名称可用。${NC}"
        break
    fi
done

# 2. 输入网段 + 判断是否冲突
while true; do
    read -p "请输入网段（CIDR，如 10.10.10.0/24）: " SUBNET
    CONFLICT=false
    EXISTING_SUBNETS=$(docker network inspect $(docker network ls -q) | grep -oP '"Subnet":\s*"\K[^"]+')
    for s in $EXISTING_SUBNETS; do
        if [[ "$s" == "$SUBNET" ]]; then
            CONFLICT=true
            break
        fi
    done

    if $CONFLICT; then
        echo -e "${RED}❌ 网段 [$SUBNET] 已被占用，请更换。${NC}"
    else
        echo -e "${GREEN}✅ 网段 [$SUBNET] 可用。${NC}"
        break
    fi
done

# 3. 输入网关
read -p "请输入网关（如 10.10.10.1）: " GATEWAY

# 4. 创建网络
docker network create \
  --driver bridge \
  --subnet="$SUBNET" \
  --gateway="$GATEWAY" \
  "$NET_NAME"

echo -e "${GREEN}🎉 网络 [$NET_NAME] 创建成功，子网：$SUBNET，网关：$GATEWAY${NC}"

# 5. 可选：重启使用该网络的容器
read -p "是否重启所有使用该网络 [$NET_NAME] 的容器？(y/n): " restart_flag
if [[ "$restart_flag" == "y" ]]; then
    CONTAINERS=$(docker ps -q --filter "network=$NET_NAME")
    for cid in $CONTAINERS; do
        echo -e "${YELLOW}🔄 重启容器 $cid...${NC}"
        docker restart "$cid"
    done
    echo -e "${GREEN}✅ 所有相关容器已重启。${NC}"
fi

# 6. 可选：生成网络监控脚本
read -p "是否生成自动网络监控脚本 monitor_${NET_NAME}.sh？(y/n): " mon_flag
if [[ "$mon_flag" == "y" ]]; then
    cat <<EOF > monitor_${NET_NAME}.sh
#!/bin/bash
while true; do
  if ! docker network inspect $NET_NAME >/dev/null 2>&1; then
    echo "[$(date)] 网络 [$NET_NAME] 丢失，尝试重建..."
    docker network create --driver bridge --subnet=$SUBNET --gateway=$GATEWAY $NET_NAME
  fi
  sleep 60
done
EOF
    chmod +x monitor_${NET_NAME}.sh
    echo -e "${GREEN}✅ 已生成网络守护脚本 monitor_${NET_NAME}.sh（后台监控网络是否丢失）${NC}"
fi

echo -e "${GREEN}🚀 所有操作完成，网络配置完毕。${NC}"

