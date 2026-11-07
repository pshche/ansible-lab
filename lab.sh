#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="$LAB_DIR/ansible_lab"
IMAGE="ansible-lab-target"
C1="ansible-target1"
C2="ansible-target2"
PORT1=2221
PORT2=2222
GRAFANA_PORT1=3000
GRAFANA_PORT2=3001

command -v docker >/dev/null 2>&1 || { echo "Docker не найден"; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "Ansible не найден"; exit 1; }

mkdir -p "$LAB_DIR"
cd "$LAB_DIR"

cat > Dockerfile <<'DOCKERFILE'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server python3 sudo ca-certificates curl iproute2 \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash ubuntu \
    && echo 'ubuntu:ubuntu' | chpasswd \
    && adduser ubuntu sudo \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 440 /etc/sudoers.d/ubuntu
RUN mkdir -p /var/run/sshd
EXPOSE 22 3000
CMD ["/usr/sbin/sshd", "-D"]
DOCKERFILE

if [ ! -f "$KEY" ]; then
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "ansible-lab"
elif [ ! -f "$KEY.pub" ]; then
  ssh-keygen -y -f "$KEY" > "$KEY.pub"
fi

chmod 600 "$KEY"
chmod 644 "$KEY.pub"

docker build -t "$IMAGE" .

docker rm -f "$C1" "$C2" >/dev/null 2>&1 || true

# Порты bind на 127.0.0.1 — только с этого Mac, не из сети
docker run -d --name "$C1" \
  -p 127.0.0.1:${PORT1}:22 \
  -p 127.0.0.1:${GRAFANA_PORT1}:3000 \
  "$IMAGE" >/dev/null

docker run -d --name "$C2" \
  -p 127.0.0.1:${PORT2}:22 \
  -p 127.0.0.1:${GRAFANA_PORT2}:3000 \
  "$IMAGE" >/dev/null

for c in "$C1" "$C2"; do
  docker exec -i "$c" bash -c 'mkdir -p /home/ubuntu/.ssh && cat > /home/ubuntu/.ssh/authorized_keys' < "$KEY.pub"
  docker exec "$c" chown -R ubuntu:ubuntu /home/ubuntu/.ssh
  docker exec "$c" chmod 700 /home/ubuntu/.ssh
  docker exec "$c" chmod 600 /home/ubuntu/.ssh/authorized_keys
done

# Относительные пути — репо портативно
cat > ansible.cfg <<EOF
[defaults]
inventory = inventory.yaml
remote_user = ubuntu
private_key_file = ./ansible_lab
host_key_checking = False
EOF

cat > inventory.yaml <<EOF
all:
  children:
    practicum_servers:
      hosts:
        first_server:
          ansible_host: 127.0.0.1
          ansible_port: $PORT1
        second_server:
          ansible_host: 127.0.0.1
          ansible_port: $PORT2
      vars:
        ansible_user: ubuntu
        ansible_ssh_private_key_file: "{{ playbook_dir }}/ansible_lab"
        ansible_python_interpreter: /usr/bin/python3
EOF

echo "Ждём SSH..."
ok=0
for i in {1..30}; do
  if ansible all -m ping >/tmp/ansible-lab-ping.$$ 2>&1; then
    cat /tmp/ansible-lab-ping.$$
    ok=1
    break
  fi
  sleep 1
done
rm -f /tmp/ansible-lab-ping.$$

if [ "$ok" -ne 1 ]; then
  echo "Ping не прошёл. Вывод для отладки:"
  ansible all -m ping || true
  exit 1
fi

echo
echo "Лаборатория готова: $LAB_DIR"
echo "  Grafana first_server:  http://localhost:${GRAFANA_PORT1}"
echo "  Grafana second_server: http://localhost:${GRAFANA_PORT2}"
echo "Остановить: docker rm -f $C1 $C2"