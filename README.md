# Kdmid bot

Checks ability to make an appointment to consul

## Using

Install ruby 3.1.2 with rbenv for example.

Install browser and driver: http://watir.com/guides/drivers/
You can use firefox with geckodriver.

Register on https://2captcha.com/ and get API key.

Create .env file and fill variables:

    $ cp .env.example .env

And then execute:

    $ bundle

Run checker with:

    $ ruby bot.rb
