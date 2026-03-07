RSpec.configure do |config|
  # Strategy for Mongoid (MongoDB): Delete documents after each test
  # This removes all test-created records from MongoDB collections
  # Strategy for ActiveRecord (MySQL/Refinery): Transactional wrapping
  # This wraps each test in a transaction and rolls back after completion,
  # automatically removing test-created records while preserving pre-existing data.
  
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :deletion
    DatabaseCleaner[:mongoid].clean_with(:deletion)
    
    DatabaseCleaner[:active_record].strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner[:mongoid].start
    DatabaseCleaner[:active_record].start
  end

  config.after(:each) do
    DatabaseCleaner[:mongoid].clean
    DatabaseCleaner[:active_record].clean
  end
end
