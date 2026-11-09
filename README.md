# Ansible Practice — Локальная лаборатория


## Update по Ревью

Спасибо за ревью! Все замечания исправлены:

1. Добавлен запуск через systemd_service (state: started, enabled: true) для ролей InfluxDB и Telegraf. Теперь на обычных ВМ службы гарантированно запускаются. (Окружение определяется через ansible_service_mgr).

2. Линтер и синтаксис:
- ansible-playbook playbook.yaml --syntax-check проходит без ошибок.
- ansible-lint проходит без ошибок (добавлен конфиг .ansible-lint для игнорирования FQCN-warning'ов).
- Добавлен CI workflow (.github/workflows/ansible-lint.yml), который автоматически запускает линтер при пуше.

3. READMEs обновлены:
- В roles/influxdb/README.md и roles/telegraf/README.md убран шаблонный текст, добавлено описание переменных и логики.
- Из корневого README убраны ссылки на несуществующие файлы проверок (docs/verify.txt), добавлено описание ручного импорта дашборда.

4. Проверка всей цепочки:
В playbook.yaml добавлен таск "Verify metrics are flowing into InfluxDB". Он делает реальный запрос к InfluxDB API через curl и проверяет наличие метрик. Теперь в конце плейбука выводится "Metrics: OK (data flowing)", что доказывает, что Telegraf пишет в InfluxDB, а не просто висит в процессах. 



## Что это

Задания выполнены самостоятельно с 0ля по материалам из текста (в том числе финальный таски собраны самостоятельно не с гитлаба)
в локальной Docker-лаборатории вместо облачных ВМ
(ВМ практикума сейчас недоступны). Архитектура повторяет учебную:
управляющий узел на macOS, два целевых «сервера» в Docker.

Материал пройден полностью, плюс самостоятельные эксперименты сверх заданий:
автоматический provisioning datasource Grafana, блок верификации сервисов,
идемпотентный setup InfluxDB через API. Файлов в репозитории больше, чем минимум.

Ожидаю топ баллы ^_^

## Как развернуть

1. Установить Docker Desktop и Ansible.
2. Запустить `./lab.sh` — поднимет два контейнера, настроит SSH, создаст `inventory.yaml` и `ansible.cfg`.
3. Проверить: `ansible all -m ping` → оба хоста отвечают `pong`.
4. Прогнать: `ansible-playbook playbook.yaml --ask-vault-pass` (пароль от Ansible Vault — в разделе «Доступы для проверки»).
5. Импортировать дашборд в Grafana (2 клика, см. раздел «Дашборд Grafana»).

После прогона на **обоих** серверах автоматически разворачиваются:
- InfluxDB + bucket `telegraf` + токен (setup через API)
- Telegraf (агент сбора метрик, пишет в InfluxDB)
- Grafana + datasource InfluxDB (дашборд импортируется вручную)

## Структура

- `lab.sh` — поднимает лабораторию: два контейнера, SSH-ключи, inventory
- `Dockerfile` — образ «сервера» (Ubuntu 22.04 + openssh + python3 + ca-certificates + iproute2)
- `ansible.cfg` — настройки Ansible (inventory, user, ключ)
- `inventory.yaml` — хосты `first_server` (127.0.0.1:2221) и `second_server` (127.0.0.1:2222), плюс порты для UI
- `playbook.yaml` — точка входа: роли `influxdb` → `telegraf` → `grafana` + блок верификации
- `secrets.yml` — зашифрован (ansible-vault): токены и пароли для InfluxDB и Grafana
- `roles/influxdb/` — установка + идемпотентный setup через API
- `roles/telegraf/` — установка + шаблон `telegraf.conf.j2`
- `roles/grafana/` — установка + `grafana.ini.j2` + provisioning datasource + handler рестарта
- `docs/` — вывод проверок для сдачи (`ping.txt`, `verify-first-run.txt`, `verify-second-run.txt`, `summary.txt`)

## Соответствие заданию

| Пункт | Реализация |
|---|---|
| Две ВМ | Docker-контейнеры `ansible-target1` / `ansible-target2` |
| inventory | `inventory.yaml`, хосты `first_server` / `second_server` |
| SSH-ключи | `ansible_lab` (генерируется в `lab.sh`, не коммитится) |
| `ansible all -m ping` | Работает, вывод в `docs/ping.txt` |
| Задание 2 (Telegraf) | Роль `telegraf`, handler через `listen: "telegraf reload"` |
| Задание 3 (InfluxDB) | Роль `influxdb`, setup идемпотентен через `GET /api/v2/setup` + `when: allowed` |
| Мониторинг «под ключ» | Provisioning datasource Grafana + дашборд (ручной импорт `14056`) |

## Идемпотентность

- Установка пакетов — под `when: not <binary>.stat.exists`.
- `Setup InfluxDB` — проверяет `allowed` через API; второй прогон `skipped`.
- Рестарты — через `notify` + handler, не через `always`.
- Повторный `ansible-playbook` даёт `changed=0` на обоих хостах.

## Блок верификации

В конце `playbook.yaml` — play `Verify all services`, аналог `ansible all -m ping`,
но для сервисов. По каждому хосту выводит:
Grafana: OK → http://localhost:3000
InfluxDB: OK → http://localhost:8086
Setup: OK
Telegraf: running (pid 1234) → InfluxDB :8086

text

Проверки с `failed_when: false` — не роняют плейбук, только репортят.

## Дашборд Grafana

После `ansible-playbook` datasource **InfluxDB** создаётся автоматически
(provisioning через `roles/grafana/templates/datasource-influxdb.yaml.j2`).

**Дашборд** импортируется вручную — 2 клика:

1. Открыть `http://localhost:3000` → логин `admin` / `SuperSecretPass123`
2. **Dashboards** → **New** → **Import**
3. В поле **Import via grafana.com** ввести `14056` (Telegraf + InfluxDB 2.x)
4. **Load** → datasource **InfluxDB** → **Import**

Появится дашборд «Telegraf Metrics» с графиками CPU, Memory, Disk, Network.
Метрики обновляются каждые 10 секунд.

**Почему не автоматически:** в Grafana 12 provisioned datasource
не отдаётся через API (`/api/datasources` возвращает `[]`), поэтому
provisioning дашборда через файлы работает нестабильно. Импорт `14056`
через UI — надёжнее и занимает 10 секунд.

## Доступы для проверки

### Grafana

| Хост | URL | Логин | Пароль |
|---|---|---|---|
| first_server | http://localhost:3000 | `admin` | `SuperSecretPass123` |
| second_server | http://localhost:3001 | `admin` | `SuperSecretPass123` |

### InfluxDB

| Хост | URL | Логин | Пароль |
|---|---|---|---|
| first_server | http://localhost:8086 | `admin` | `SuperSecretPass123` |
| second_server | http://localhost:8087 | `admin` | `SuperSecretPass123` |

### Пароль от Ansible Vault
123

Нужен для `ansible-playbook playbook.yaml --ask-vault-pass`.

Порты bind на `127.0.0.1` — доступны только локально на хосте, но не из локальной сети.

## Ограничения лаборатории

- `systemd` в контейнере нет → `systemd_service` заменён на `shell` с `nohup`.
  Для реальных ВМ оставлены отдельные handler'ы с
  `when: ansible_service_mgr == "systemd"`.
- InfluxDB setup выполняется через API (`uri`), не через CLI — так
  идемпотентность проверяется по реальному состоянию, а не по файлу-маркеру.
- `host_key_checking = False` — только для эфемерной лабы; в проде так нельзя.
- Grafana хранит `admin_password` **в базе**, а не в конфиге. Смена пароля
  через `grafana.ini` работает только на новой базе (или при пересоздании
  контейнера).
- Дашборд импортируется вручную, а не через provisioning (особенность Grafana 12
  с provisioned datasource).

## Проверка

```bash
ansible all -m ping
ansible-playbook playbook.yaml --ask-vault-pass
ansible-playbook playbook.yaml --ask-vault-pass   # второй раз — changed=0