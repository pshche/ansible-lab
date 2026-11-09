# Ansible role: influxdb

Устанавливает InfluxDB 2.x и выполняет идемпотентный setup (org, bucket, user, token).

## Требования

- Debian-based система (Ubuntu 22.04)
- systemd (для реальных ВМ) **или** shell-запуск (для контейнеров).
  Окружение определяется автоматически через `ansible_service_mgr`:
  на ВМ — `systemd_service`, в контейнере — `nohup` + проверка порта `8086`.

## Переменные

| Переменная | По умолчанию | Описание |
|---|---|---|
| `influxdb_version` | `2.7.10` | Версия пакета |
| `influx_ip` | `127.0.0.1` | IP для API |
| `influx_username` | `admin` | Имя админа (setup) |
| `influx_password` | `CHANGE_ME` | Пароль (переопределяется из `secrets.yml`) |
| `influx_org` | `mephi-lab` | Организация |
| `influx_bucket` | `telegraf` | Bucket для метрик |
| `influx_token` | `CHANGE_ME` | Токен API (переопределяется из `secrets.yml`) |

## Идемпотентность

- Установка пакета — под `when: not influx_binary.stat.exists`.
- Setup — `GET /api/v2/setup` → `allowed: false` (уже настроено) → `skipped`.
- Второй прогон роли даёт `changed=0`.