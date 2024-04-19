require 'selenium/webdriver'

# access local chrome browser greater than version 59
# Capybara.javascript_driver = :selenium_chrome
# Capybara.javascript_driver = :selenium_chrome_headless

# head browsing, for debugging, see browser window
Capybara.register_driver :selenium_chrome_in_container do |app|
  Capybara::Selenium::Driver.new app,
                                 browser: :remote,
                                 url: 'http://selenium-chrome:4444/wd/hub',
                                 desired_capabilities: :chrome
end

Capybara.register_driver :remote_selenium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  # options.add_argument('--window-size=1400,1400')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    url: 'http://selenium-chrome:4444/wd/hub',
    options: options
  )
end

Capybara.register_driver :remote_selenium_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    url: 'http://selenium-chrome:4444/wd/hub',
    options: options
  )
end
