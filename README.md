# Kdmid bot

Checks ability to make an appointment to consul

## Setup

Register on https://2captcha.com/ and get API key.

Create .env file and fill variables:

    $ cp .env.example .env

### Docker

    $ bin/build && bin/start

Run bot with:

    $ bin/bot

**How to see the browser?**

View the firefox node via VNC (password: secret):

    $ open vnc://localhost:5900

### Locally

Install ruby 3.1.2 with rbenv for example.

Install browser and driver: http://watir.com/guides/drivers/
You can use firefox with geckodriver.

Setup dependencies:

    $ bundle

Run bot with:

    $ ruby bot.rb

## Issues

Problems with hcaptcha: do not pass it periodically
