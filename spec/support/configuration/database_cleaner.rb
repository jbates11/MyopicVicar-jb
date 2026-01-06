RSpec.configure do |config|
  # 1. Set Mongoid's default cleaning strategy to "delete documents".
  # 2. Immediately wipe all collections in the test database.
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :deletion
    DatabaseCleaner[:mongoid].clean_with(:deletion)
  end

  config.before(:each) do
    DatabaseCleaner[:mongoid].start
  end

  config.after(:each) do
    DatabaseCleaner[:mongoid].clean
  end

end
