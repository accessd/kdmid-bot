# Kdmid bot

Checks ability to make an appointment to consul

## Setup

Register on https://2captcha.com/ and get API key.

Get order id and code from the link http://istanbul.kdmid.ru/queue/OrderInfo.aspx?id=ORDER_ID&cd=CODE

Create .env file and replace variables with your values:

```sh
cp .env.example .env
```

### Docker

```sh
bin/build && bin/start
```

Run bot with:

```sh
bin/bot
```

#### Несколько заявлений

Если у вас несколько заявлений, создайте `.env.<var>` и `compose.<var>.yml` под файлы под каждое заявление и запускайте с подключением патча:

```sh
docker compose -f docker-compose.yml -f compose.<var>.yml up bot
```

**How to see the browser?**

View the firefox node via VNC (password: secret):

```sh
open vnc://localhost:5900
```

> **_NOTE:_**  If you want to access VNC via any public network interface you will need to update listening address in `docker-compose.yml` for `node-firefox` service

After testing that bot works properly put command to run bot in crontab, like:

> **WARNING:** Внимание! При повторяющихся запросах к системе в течение дня более 24 раз Ваша заявка будет заблокирована.

```sh
0 12 * * * cd /path/to/the/bot; bin/bot >> kdmid-bot.log 2>&1
```

Than you can look at the log file by:

```sh
tail -f kdmid-bot.log
```

### Locally

Install ruby 3.1.2 with rbenv for example.

Install browser and driver: http://watir.com/guides/drivers/
You can use firefox with geckodriver.

Setup dependencies:

```sh
bundle
```

Run bot with:

```sh
ruby bot.rb
```

## Issues

Problems with hcaptcha: do not pass it periodically
