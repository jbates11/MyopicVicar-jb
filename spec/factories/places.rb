FactoryBot.define do
  factory :place do
    sequence(:place_name) { |n| "Guildford#{n}" }
    # place_name   { "Norfolk" }
    chapman_code { "NFK" }
    country      { "England" }
    county       { "Norfolk" }
    latitude     { "52.6309" }
    longitude    { "1.2974" }
    ucf_list     { {} }

    # trait :with_data do
    #   after(:create) do |place|
    #     create(:freereg1_csv_file, place_name: place.place_name)
    #   end
    # end
    
  end
end
