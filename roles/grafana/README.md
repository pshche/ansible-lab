# Ansible role: grafana

Устанавливает Grafana, настраивает базовый конфиг и автоматически разворачивает datasource для InfluxDB (через provisioning).

## Требования

- Debian-based система (Ubuntu 22.04)
- systemd (для реальных ВМ) **или** shell-запуск (для контейнеров).
  Окружение определяется автоматически через `ansible_service_mgr`:
  на ВМ — `systemd_service`, в контейнере — `nohup` + проверка порта `3000`.

## Переменные

| Переменная | По умолчанию | Описание |
|---|---|---|
| `grafana_version` | `12.1.0` | Версия пакета |
| `grafana_admin` | `admin` | Логин администратора |
| `grafana_password` | `CHANGE_ME` | Пароль (переопределяется из `secrets.yml`) |
| `grafana_databasepath` | `grafananew.db` | Имя файла базы данных SQLite |
| `env_type` | `development` | Влияет на уровень логирования (`info` / `debug`) |
| `grafana_log_mode` | `file` | Режим логирования (`file` / `syslog`) |

*Примечание: остальные переменные для секции `[log]` (`grafana_logs_path`, `grafana_max_lines` и т.д.) задаются в `defaults/main.yml`.*

## Идемпотентность

- Установка пакета — под `when: not grafana_binary.stat.exists`.
- Конфиг и datasource — `template` + `notify: "grafana reload"`.
- Принудительный вызов `meta: flush_handlers` гарантирует, что Grafana перезапустится с новым конфигом до того, как плейбук пойдёт дальше.
- Второй прогон роли даёт `changed=0`.

## Дашборд и Datasource

- **Datasource** создаётся автоматически через файл `datasource-influxdb.yaml.j2`.
  *Особенность Grafana 12:* provisioned datasource **не отдается** через API (`/api/datasources` возвращает `[]`), но **успешно работает** в UI (зеленая галочка, графики строятся).
- **Дашборд** необходимо импортировать вручную (2 клика): **Dashboards → New → Import → `14056`** (Telegraf + InfluxDB 2.x). В будущем можно автоматизировать через `dashboard-provider`, но для тестовой лабы достаточно ручного импорта.

## Ограничения

- Grafana хранит `admin_password` **в базе**, а не в конфиге. Если база уже создана, смена пароля через `grafana.ini` не применится. Требуется пересоздание контейнера или смена `grafana_databasepath`.

## Пример

```yaml
- hosts: servers
  become: yes
  vars_files:
    - secrets.yml
  roles:
    - grafana