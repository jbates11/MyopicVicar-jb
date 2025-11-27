FactoryBot.define do
  factory :place do
    sequence(:place_name) { |n| "TestTown#{n}" }
    chapman_code { "ENG" }
    country { "England" }
    county { "Bedfordshire" }
    grid_reference { "SX5055" }
    ucf_list {
      {
        "valid_file_id" => { "some" => "data" },
        "invalid_file_id" => { "other" => "data" }
      }
    }
  end
end
