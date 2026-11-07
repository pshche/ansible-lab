# Ansible Practice — Локальная лаборатория

## Что это

Задания выполнены в локальной Docker-лаборатории вместо облачных ВМ
(ВМ практикума сейчас недоступны). Архитектура повторяет учебную:
управляющий узел на macOS, два целевых «сервера» в Docker.

Материал прошёл полностью, включая самостоятельные эксперименты сверх
заданий — поэтому в репозитории больше файлов, чем требует минимум.

## Как развернуть

1. Установить Docker Desktop и Ansible.
2. Запустить `./lab.sh` — поднимет два контейнера, настроит SSH, создаст `inventory.yaml` и `ansible.cfg`.
3. Проверить: `ansible all -m ping` → оба хоста отвечают `pong`.
4. Прогнать: `ansible-playbook playbook.yaml --ask-vault-pass` (пароль от Ansible Vault: 123).

## Структура

- `lab.sh` — поднимает лабораторию: два контейнера, SSH-ключи, inventory
- `Dockerfile` — образ «сервера» (Ubuntu 22.04 + openssh + python3 + ca-certificates)
- `ansible.cfg` — настройки Ansible (inventory, user, ключ)
- `inventory.yaml` — хосты `first_server` (127.0.0.1:2221) и `second_server` (127.0.0.1:2222)
- `playbook.yaml` — точка входа: роли `influxdb` → `telegraf` → `grafana` + блок верификации
- `secrets.yml` — зашифрован (ansible-vault): токены и пароли для InfluxDB и Grafana
- `roles/influxdb/` — установка + идемпотентный setup через API
- `roles/telegraf/` — установка + шаблон `telegraf.conf.j2`
- `roles/grafana/` — установка + шаблон `grafana.ini.j2` + handler рестарта
- `docs/` — вывод проверок для сдачи (`verify.txt`, `ping.txt`)

## Соответствие заданию

| Пункт | Реализация |
|---|---|
| Две ВМ | Docker-контейнеры `ansible-target1` / `ansible-target2` |
| inventory | `inventory.yaml`, хосты `first_server` / `second_server` |
| SSH-ключи | `ansible_lab` (генерируется в `lab.sh`, не коммитится) |
| `ansible all -m ping` | Работает, вывод в `docs/ping.txt` |
| Задание 2 (Telegraf) | Роль `telegraf`, handler через `listen: "telegraf reload"` |
| Задание 3 (InfluxDB) | Роль `influxdb`, setup идемпотентен через `GET /api/v2/setup` + `when: allowed` |

## Идемпотентность

- Установка пакетов — под `when: not <binary>.stat.exists`.
- `Setup InfluxDB` — проверяет `allowed` через API; второй прогон `skipped`.
- Рестарты — через `notify` + handler, не через `always`.
- Повторный `ansible-playbook` даёт `changed=0` на обоих хостах.

## Блок верификации

В конце `playbook.yaml` — play `Verify all services`, аналог `ansible all -m ping`,
но для сервисов. По каждому хосту выводит:
Grafana: OK
InfluxDB: OK
Setup: OK
Telegraf: running (pid ...)



Проверки с `failed_when: false` — не роняют плейбук, только репортят.

## Доступ к сервисам с Mac

| Сервис | Адрес |
|---|---|
| Grafana `first_server` | http://localhost:3000 |
| Grafana `second_server` | http://localhost:3001 |
| InfluxDB `first_server` | http://localhost:8086 |
| InfluxDB `second_server` | http://localhost:8087 |

Порты bind на `127.0.0.1` — доступны только с этого Mac, не из локальной сети.

## Ограничения лаборатории

- `systemd` в контейнере нет → `systemd_service` заменён на `shell` с `nohup`.
  Для реальных ВМ оставлены отдельные handler'ы с
  `when: ansible_service_mgr == "systemd"`.
- InfluxDB setup выполняется через API (`uri`), не через CLI — так
  идемпотентность проверяется по реальному состоянию, а не по файлу-маркеру.
- `host_key_checking = False` — только для эфемерной лабы; в проде так нельзя.

## Проверка

```bash
ansible all -m ping
ansible-playbook playbook.yaml --ask-vault-pass
ansible-playbook playbook.yaml --ask-vault-pass   # второй раз — changed=0



Вывод обеих проверок — в docs/verify.txt.

Безопасность
Приватный ключ ansible_lab — в .gitignore, не коммитится.

secrets.yml зашифрован через ansible-vault; пароль хранится вне репозитория.

Порты bind на 127.0.0.1, наружу не светятся.
