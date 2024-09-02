require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'telegram/bot'

Watir.default_timeout = 60

class Bot
  attr_reader :link, :browser, :client, :current_time
  PASS_CAPTCHA_ATTEMPTS_LIMIT = 5

  def initialize
    @link = "http://#{ENV.fetch('KDMID_SUBDOMAIN')}.kdmid.ru/queue/OrderInfo.aspx?id=#{ENV.fetch('ORDER_ID')}&cd=#{ENV.fetch('CODE')}"
    @client = TwoCaptcha.new(ENV.fetch('TWO_CAPTCHA_KEY'))
    @current_time = Time.now.utc.to_s
    puts 'Init...'

    options = {
      accept_insecure_certs: true,
    }
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
      bot.api.send_message(chat_id: ENV['TELEGRAM_CHAT_ID'], text: message, parse_mode: 'Markdown')
    end
  end

  def send_scr(photo_path)
    return unless ENV['TELEGRAM_TOKEN']
  
    Telegram::Bot::Client.run(ENV['TELEGRAM_TOKEN']) do |bot|
      bot.api.send_photo(chat_id: ENV['TELEGRAM_CHAT_ID'], photo: Faraday::UploadIO.new(photo_path, 'image/png'))
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

  def pass_ddgcaptcha
    attempt = 1
    sleep 5

    while browser.div(id: 'ddg-captcha').exists? && attempt <= PASS_CAPTCHA_ATTEMPTS_LIMIT
      puts "attempt: [#{attempt}] let's find the ddg captcha image..."

      checkbox = browser.div(id: 'ddg-captcha')
      checkbox.wait_until(timeout: 60, &:exists?)
      checkbox.click

      captcha_image = browser.iframe(id: 'ddg-iframe').images(class: 'ddg-modal__captcha-image').first
      captcha_image.wait_until(timeout: 5, &:exists?)

      puts 'save captcha image to file...'
      sleep 3
      image_filepath = "./captches/#{current_time}.png"
      base64_to_file(captcha_image.src, image_filepath)

      puts 'decode captcha...'
      captcha = client.decode!(path: image_filepath)
      captcha_code = captcha.text
      puts "captcha_code: #{captcha_code}"

      # puts 'Enter code:'
      # code = gets
      # puts code

      text_field = browser.iframe(id: 'ddg-iframe').text_field(class: 'ddg-modal__input')
      text_field.set captcha_code
      browser.iframe(id: 'ddg-iframe').button(class: 'ddg-modal__submit').click

      attempt += 1
      sleep 15
    end
  end

  def base64_to_file(base64_data, filename=nil)
    start_regex = /data:image\/[a-z]{3,4};base64,/
    filename ||= SecureRandom.hex

    regex_result = start_regex.match(base64_data)
    start = regex_result.to_s

    File.open(filename, 'wb') do |file|
      file.write(Base64.decode64(base64_data[start.length..-1]))
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
    target_image_path = image_filepath
    
    File.write(image_filepath, captcha_image.to_png)

    img = MiniMagick::Image.open(image_filepath)
    if img.width == 600 && img.height == 200
      puts 'crop image'

      cropped_image_filepath = "./captches/#{current_time}.crop.png"
      processed = ImageProcessing::MiniMagick.source(image_filepath).crop(200, 0, 200, 200).call

      FileUtils.cp(processed.path, cropped_image_filepath)
      target_image_path = cropped_image_filepath
    end

    puts 'decode captcha...'
    captcha = client.decode!(path: target_image_path)
    captcha_code = captcha.text
    puts "captcha_code: #{captcha_code}"

    # puts 'Enter code:'
    # code = gets
    # puts code

    text_field = browser.text_field(id: 'ctl00_MainContent_txtCode')
    text_field.set captcha_code
  end

  def click_make_appointment_button

    # Найти элемент по ID ctl00_MainContent_Content и получить его текст
    content_element = browser.span(id: 'ctl00_MainContent_Content')
    content_text = content_element.text
    # Отправить текст в Telegram
    notify_user("*Проверка:*\n\n#{content_text}")

    make_appointment_btn = browser.button(id: 'ctl00_MainContent_ButtonB')
    make_appointment_btn.wait_until(timeout: 60, &:exists?)
    make_appointment_btn.click
  end

  def save_page
    browser.screenshot.save "./screenshots/#{current_time}.png"
    File.open("./pages/#{current_time}.html", 'w') { |f| f.write browser.html }
    send_scr("./screenshots/#{current_time}.png")
  end

  def stop_text_found?
    failure_texts = [
      'Извините, но в настоящий момент',
      'Свободное время в системе записи отсутствует',
      'Для проверки наличия свободного времени',
      'нет свободного времени',
      'Bad Gateway'
    ]
    if failure_texts.any? { |text| browser.text.include?(text) }
      raise "Failure text found in the page."
    end
    true
  end

  def get_center_panel_text
    center_panel = browser.td(id: 'center-panel')
    center_panel_text = center_panel.text
    center_panel_text
  end

  def check_queue
    puts "===== Current time: #{current_time} ====="
    browser.goto link

    pass_hcaptcha
    pass_ddgcaptcha

    browser.button(id: 'ctl00_MainContent_ButtonA').wait_until(timeout: 30, &:exists?)

    pass_captcha_on_form

    browser.button(id: 'ctl00_MainContent_ButtonA').click

    sleep 3

    if browser.alert.exists?
      browser.alert.ok
    end

    sleep 1

    pass_hcaptcha
    pass_ddgcaptcha

    click_make_appointment_button

    save_page
    
    panel_text = get_center_panel_text

    unless stop_text_found?
      notify_user("*Появилось место для записи!*\n\n#{panel_text}")
    end

    browser.close
    puts '=' * 50
  rescue Exception => e
    notify_user("*Мест нет!*\n\n#{panel_text}")
    sleep 3
    browser.close
    raise e
  end
end

Bot.new.check_queue
