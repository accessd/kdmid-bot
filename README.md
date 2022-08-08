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

### How to see browser?

Browser starts with Selenium node. So, after having started the Selenium hub and nodes (bin/start),
open a browser and go to http://localhost:4444/ui#/sessions,
then click the 'play' button to connect with VNC (password: secret).

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
