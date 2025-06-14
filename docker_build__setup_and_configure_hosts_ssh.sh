#!/bin/bash

CONFIG_FILE="hosts_info.txt"
CONTAINER_NAME=dashboard

# 第一步：输入主机信息并生成配置文件
echo "📝 请输入要配置免密的主机信息（输入空 IP 结束）："
> "$CONFIG_FILE"  # 清空旧文件

while true; do
    read -p "👉 主机 IP（回车结束）: " IP
    [[ -z "$IP" ]] && break

    read -p "👤 用户名: " USER
    read -s -p "🔑 密码: " PASS
    echo

    echo "$IP $USER $PASS" >> "$CONFIG_FILE"
    echo "✅ 添加主机：$IP ($USER)"
done

echo
echo "📁 已写入配置文件 $CONFIG_FILE："
cat "$CONFIG_FILE"
echo

# 第二步：启动容器（如未启动）
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🚀 启动容器 ${CONTAINER_NAME}..."
    docker run -d -p 5000:5000 --name $CONTAINER_NAME host-monitor
else
    echo "✅ 容器 ${CONTAINER_NAME} 已存在，跳过启动"
    docker start $CONTAINER_NAME > /dev/null
fi

sleep 2

# 第三步：生成密钥
docker exec $CONTAINER_NAME bash -c "[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N \"\" -q"

# 安装 expect
docker exec $CONTAINER_NAME bash -c "apt update && apt install -y expect" > /dev/null

# 第四步：执行免密配置
while read -r IP USER PASS; do
    if [[ -z "$IP" || -z "$USER" || -z "$PASS" ]]; then
        echo "⚠️  跳过无效行: $IP $USER $PASS"
        continue
    fi

    echo "🔗 正在配置免密登录：$USER@$IP"

    docker exec -i $CONTAINER_NAME bash -c "
    expect <<EOF
    set timeout 10
    spawn ssh-copy-id ${USER}@${IP}
    expect {
        \"*yes/no*\" { send \"yes\r\"; exp_continue }
        \"*password:\" { send \"${PASS}\r\" }
    }
    expect eof
EOF
    "

    echo "✅ $USER@$IP 配置完成"
done < "$CONFIG_FILE"

echo "🎉 所有主机免密配置完成！"

