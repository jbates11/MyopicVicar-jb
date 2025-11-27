FactoryBot.define do
  factory :freereg1_csv_file do
    sequence(:file_name) { |n| "file#{n}.csv" }
    record_type { "ba" } # baptism
    chapman_code { "ENG" }
    place_name { "TestTown" }
    # userid_lower_case {"nil"}
    sequence(:userid) { |n| "TestUser#{n}" }
    association :register
  end
end
