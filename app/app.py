from flask import Flask, render_template, request, redirect, session, send_file, jsonify
import subprocess

app = Flask(__name__)
app.secret_key = 'your_secret_key'

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form['username'] == 'admin' and request.form['password'] == '123456':
            session['user'] = 'admin'
            return redirect('/dashboard')
        else:
            return render_template('login.html', error='用户名或密码错误')
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect('/')
    return render_template('dashboard.html')

@app.route('/logout')
def logout():
    session.pop('user', None)
    return redirect('/')

@app.route('/hosts')
def host_editor():
    if 'user' not in session:
        return redirect('/')
    return render_template('hosts.html')

@app.route('/api/hosts', methods=['GET'])
def get_hosts():
    hosts = []
    with open('/app/hosts') as f:
        for line in f:
            if line.startswith('Host-'):
                parts = line.strip().split()
                if len(parts) >= 2:
                    name = parts[0]
                    ip = parts[1].split('=')[1]
                    hosts.append({'name': name, 'ip': ip})
    return jsonify(hosts)

@app.route('/api/hosts', methods=['POST'])
def add_host():
    data = request.get_json()
    name = data.get('name')
    ip = data.get('ip')
    if not name or not ip:
        return 'Missing name or ip', 400
    with open('/app/hosts', 'a') as f:
        f.write(f"{name} ansible_host={ip}\n")
    return 'OK', 200

@app.route('/api/hosts/<name>', methods=['DELETE'])
def delete_host(name):
    with open('/app/hosts') as f:
        lines = f.readlines()
    with open('/app/hosts', 'w') as f:
        for line in lines:
            if not line.startswith(name + ' '):
                f.write(line)
    return 'OK', 200

@app.route('/api/hosts/<name>', methods=['PUT'])
def update_host(name):
    data = request.get_json()
    new_ip = data.get('ip')
    with open('/app/hosts') as f:
        lines = f.readlines()
    with open('/app/hosts', 'w') as f:
        for line in lines:
            if line.startswith(name + ' '):
                f.write(f"{name} ansible_host={new_ip}\n")
            else:
                f.write(line)
    return 'OK', 200

# @app.route('/status')
# def status():
#     import subprocess
#     hosts = {}
#     with open('/app/result.txt') as f:
#         for line in f:
#             if ': ' in line:
#                 host, status = line.strip().split(': ')
#                 hosts[host] = {'status': status, 'resources': []}
#
#     try:
#         result = subprocess.getoutput(
#             "ansible all -i /app/hosts -a \"free -m && df -h --total | grep -E 'total|Mem:' && top -bn1 | grep Cpu\""
#         )
#         current_host = ""
#         for line in result.splitlines():
#             if line.startswith('Host-'):
#                 current_host = line.split()[0]
#             elif line.strip().startswith('Mem:') and current_host in hosts:
#                 parts = line.split()
#                 if len(parts) >= 4:
#                     mem_info = f"内存：总 {parts[1]}MB，已用 {parts[2]}MB，空闲 {parts[3]}MB"
#                     hosts[current_host]['resources'].append(mem_info)
#             elif line.strip().startswith('total') and current_host in hosts:
#                 parts = line.split()
#                 if len(parts) >= 4:
#                     disk_info = f"磁盘：总 {parts[1]}，已用 {parts[2]}，可用 {parts[3]}"
#                     hosts[current_host]['resources'].append(disk_info)
#             elif "Cpu" in line and current_host in hosts:
#                 # 处理 top 输出，如：Cpu(s):  1.0%us,  0.5%sy,  0.0%ni, 97.5%id,...
#                 line = line.replace(",", "").replace("Cpu(s):", "")
#                 usage_parts = line.split()
#                 if "%id" in usage_parts[-1]:
#                     idle = float(usage_parts[-2])
#                     cpu_usage = 100 - idle
#                 else:
#                     try:
#                         # 通用处理方式，找出 idle 后减去
#                         idx = usage_parts.index("id")
#                         idle = float(usage_parts[idx - 1])
#                         cpu_usage = 100 - idle
#                     except:
#                         cpu_usage = -1
#                 cpu_info = f"CPU 占用率：{cpu_usage:.1f}%" if cpu_usage >= 0 else "CPU 占用率获取失败"
#                 hosts[current_host]['resources'].append(cpu_info)
#
#     except Exception as e:
#         print("资源信息获取失败:", e)
#
#     # 添加资源失败提示
#     for host in hosts:
#         if hosts[host]['status'] == 'online' and not hosts[host]['resources']:
#             hosts[host]['resources'] = ['资源信息获取失败']
#         elif hosts[host]['status'] == 'offline':
#             hosts[host]['resources'] = ['资源信息获取失败']
#
#     return jsonify(hosts)



@app.route('/status')
def status():
    hosts = {}

    with open('/app/hosts') as f:
        for line in f:
            if line.startswith('Host-'):
                name = line.split()[0]
                hosts[name] = {'status': 'offline', 'resources': ['资源信息获取失败']}

    try:
        result = subprocess.getoutput(
            "ansible all -i /app/hosts -a \"sh -c 'free -m; echo ---; df -h --total | grep total; echo ---; top -bn1 | grep Cpu'\""
        )

        current_host = ""
        resource_lines = []  # 缓存每台主机的资源信息

        for line in result.splitlines():
            if line.startswith('Host-') and '| CHANGED' in line:
                current_host = line.split('|')[0].strip()
                if current_host in hosts:
                    hosts[current_host]['status'] = 'online'
                    resource_lines = []  # 每次新主机开始前重置
            elif line.startswith('Host-') and '| UNREACHABLE' in line:
                current_host = ""
            elif current_host in hosts:
                if line.strip().startswith('Mem:'):
                    parts = line.split()
                    if len(parts) >= 4:
                        mem_info = f"内存：总 {parts[1]}MB，已用 {parts[2]}MB，空闲 {parts[3]}MB"
                        resource_lines.append(mem_info)
                elif line.strip().startswith('total') and current_host in hosts and 'G' in line:
                    parts = line.split()
                    if len(parts) >= 4:
                        disk_info = f"磁盘：总 {parts[1]}，已用 {parts[2]}，可用 {parts[3]}"
                        resource_lines.append(disk_info)
                elif "Cpu" in line:
                    line = line.replace(",", "").replace("Cpu(s):", "")
                    usage_parts = line.split()
                    try:
                        idx = usage_parts.index("id")
                        idle = float(usage_parts[idx - 1])
                        cpu_usage = 100 - idle
                        cpu_info = f"CPU 占用率：{cpu_usage:.1f}%"
                    except:
                        cpu_info = "CPU 占用率获取失败"
                    resource_lines.append(cpu_info)

                # 如果收集到3条资源信息，则保存到hosts中
                if len(resource_lines) == 3:
                    hosts[current_host]['resources'] = resource_lines
    except Exception as e:
        print("资源信息获取失败:", e)

    return jsonify(hosts)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
