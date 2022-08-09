require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'telegram/bot'

Watir.default_timeout = 60

class Bot
  attr_reader :link, :browser, :client, :current_time

  def initialize
    @link = "http://#{ENV.fetch('KDMID_SUBDOMAIN')}.kdmid.ru/queue/OrderInfo.aspx?id=#{ENV.fetch('ORDER_ID')}&cd=#{ENV.fetch('CODE')}"
    @client = TwoCaptcha.new(ENV.fetch('TWO_CAPTCHA_KEY'))
    @current_time = Time.now.utc.to_s
    puts 'Init...'

    options = {}
    if ENV['BROWSER_PROFILE']
      options.merge!(profile: ENV['BROWSER_PROFILE'])
    end
    @browser = Watir::Browser.new(
      ENV.fetch('BROWSER').to_sym,
      url: "http://#{ENV.fetch('HUB_HOST')}/wd/hub",
      options: options
    )
  end

  def notify_user(message)
    puts message
    # `say "#{message}"`
    return unless ENV['TELEGRAM_TOKEN']

    Telegram::Bot::Client.run(ENV['TELEGRAM_TOKEN']) do |bot|
      bot.api.send_message(chat_id: ENV['TELEGRAM_CHAT_ID'], text: message)
    end
  end

  def pass_hcaptcha
    sleep 5

    return unless browser.div(id: 'h-captcha').exists?

    sitekey = browser.div(id: 'h-captcha').attribute_value('data-sitekey')
    puts "sitekey: #{sitekey} url: #{browser.url}"

    captcha = client.decode_hcaptcha!(sitekey: sitekey, pageurl: browser.url)
    captcha_response = captcha.text
    puts "captcha_response: #{captcha_response}"

    3.times do |i|
      puts "attempt: #{i}"
      sleep 2
      ['h-captcha-response', 'g-recaptcha-response'].each do |el_name|
        browser.execute_script(
          "document.getElementsByName('#{el_name}')[0].style = '';
           document.getElementsByName('#{el_name}')[0].innerHTML = '#{captcha_response.strip}';
           document.querySelector('iframe').setAttribute('data-hcaptcha-response', '#{captcha_response.strip}');"
        )
      end
      sleep 3
      browser.execute_script("cb();")
      sleep 3
      break unless browser.div(id: 'h-captcha').exists?
    end

    if browser.alert.exists?
      browser.alert.ok
    end
  end

  def pass_captcha_on_form
    sleep 3

    if browser.alert.exists?
      browser.alert.ok
      puts 'alert found'
    end

    puts "let's find the captcha image..."
    captcha_image = browser.images(id: 'ctl00_MainContent_imgSecNum').first
    captcha_image.wait_until(timeout: 5, &:exists?)

    puts 'save captcha image to file...'
    image_filepath = "./captches/#{current_time}.png"
    File.write(image_filepath, captcha_image.to_png)

    puts 'decode captcha...'
    captcha = client.decode!(path: image_filepath)
    captcha_code = captcha.text
    puts "captcha_code: #{captcha_code}"

    # puts 'Enter code:'
    # code = gets
    # puts code

    text_field = browser.text_field(id: 'ctl00_MainContent_txtCode')
    text_field.set captcha_code
  end

  def click_make_appointment_button
    make_appointment_btn = browser.button(id: 'ctl00_MainContent_ButtonB')
    make_appointment_btn.wait_until(timeout: 60, &:exists?)
    make_appointment_btn.click
  end

  def save_page
    browser.screenshot.save "./screenshots/#{current_time}.png"
    File.open("./pages/#{current_time}.html", 'w') { |f| f.write browser.html }
  end

  def check_queue
    puts "===== Current time: #{current_time} ====="
    browser.goto link

    pass_hcaptcha

    browser.wait_until(timeout: 30) { |b| b.title == 'Очередь в Стамбуле' }

    pass_captcha_on_form

    browser.button(id: 'ctl00_MainContent_ButtonA').click

    sleep 3

    if browser.alert.exists?
      browser.alert.ok
    end

    sleep 1

    pass_hcaptcha

    click_make_appointment_button

    save_page

    unless browser.p(text: /Извините, но в настоящий момент/).exists?
      notify_user('New time for an appointment found!')
    end

    browser.close
    puts '=' * 50
  rescue Exception => e
    browser.close
    notify_user('exception!')
    raise e
  end
end

Bot.new.check_queue
