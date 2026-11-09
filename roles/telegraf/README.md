# Ansible role: telegraf

Устанавливает Telegraf и разворачивает конфиг для отправки метрик в InfluxDB 2.x.

## Требования

- Debian-based система
- InfluxDB **настроена** (роль `influxdb` идёт раньше) — Telegraf использует
  `influx_token` / `influx_org` из общего контракта переменных.
- Окружение определяется через `ansible_service_mgr`: systemd → `systemd_service`,
  иначе → `nohup` + проверка порта `8125`.

## Идемпотентность

- Установка пакета — `when: not telegraf_binary.stat.exists`.
- Конфиг — `template` + `notify: "telegraf reload"`.
- Второй прогон даёт `changed=0`.