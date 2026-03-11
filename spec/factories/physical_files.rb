FactoryBot.define do
  factory :physical_file do
    userid { "USER001" }
    file_name { "test.csv" }
    base { false }
    file_processed { false }
    waiting_to_be_processed { false }
  end
end
