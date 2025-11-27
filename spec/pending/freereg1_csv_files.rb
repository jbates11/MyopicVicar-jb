FactoryBot.define do
  factory :freereg1_csv_file do
    sequence(:id) { |n| "file#{n}" }
    county { "DEV" }
    place { "TestTown" }

    trait :invalid do
      county { "XX" }
      place { "WrongTown" }
    end
  end
end
