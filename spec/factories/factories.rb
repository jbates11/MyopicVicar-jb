FactoryBot.define do
  factory :place do
    sequence(:place_name) { |n| "TestPlace#{n}" }
    chapman_code { "ENG" }
    country { "England" }
    county { "Bedfordshire" }
    grid_reference { "SX5055" }
    latitude { "51.5074" }
    longitude { "-0.1278" }
    disabled { "false" }
    data_present { false }
    ucf_list { {} }
    old_ucf_list { {} }

    trait :with_churches do
      after(:create) do |place|
        create_list(:church, 3, place: place)
      end
    end

    trait :with_search_records do
      after(:create) do |place|
        create_list(:search_record, 5, place: place)
      end
    end

    trait :disabled do
      disabled { "true" }
    end
  end

  factory :church do
    sequence(:church_name) { |n| "Church of #{n}" }
    denomination { "Church of England" }
    association :place

    trait :with_registers do
      after(:create) do |church|
        create_list(:register, 3, church: church)
      end
    end
  end

  factory :register do
    sequence(:register_name) { |n| "Baptisms #{n}" }
    register_type { "Baptism" }
    status { "Open" }
    quality { "Good" }
    association :church

    trait :with_csv_files do
      after(:create) do |register|
        create_list(:freereg1_csv_file, 2, register: register)
      end
    end

    trait :with_embargo_rules do
      after(:create) do |register|
        create_list(:embargo_rule, 2, register: register)
      end
    end

    trait :with_gaps do
      after(:create) do |register|
        create_list(:gap, 1, register: register)
      end
    end
  end

  factory :freereg1_csv_file do
    sequence(:file_name) { |n| "freereg_file_#{n}.csv" }
    record_type { "ba" }
    chapman_code { "ENG" }
    sequence(:place) { |n| "TestTown#{n}" }
    sequence(:userid) { |n| "user_#{n}" }
    userid_lower_case { userid.downcase }
    association :register
    userid_detail { nil }

    trait :with_entries do
      after(:create) do |file|
        create_list(:freereg1_csv_entry, 5, freereg1_csv_file: file)
      end
    end

    trait :with_errors do
      error { 3 }
      after(:create) do |file|
        create_list(:batch_error, 2, freereg1_csv_file: file)
      end
    end
  end

  factory :freereg1_csv_entry do
    sequence(:notes) { |n| "entry_#{n}" }
    # sequence(:entry_type) { |n| "entry_#{n}" }
    association :freereg1_csv_file, factory: :freereg1_csv_file

    trait :with_search_record do
      after(:create) do |entry|
        create(:search_record, freereg1_csv_entry: entry)
      end
    end

    trait :with_witnesses do
      after(:create) do |entry|
        create_list(:multiple_witness, 2, freereg1_csv_entry: entry)
      end
    end
  end

  # factory :search_record do
  #   sequence(:record_id) { |n| "rec_#{n}" }
  #   record_type { "baptism" }
  #   search_date { "1850" }
  #   freereg1_csv_entry { nil }
  #   freecen_csv_entry { nil }
  #   # place
  #   association :place, factory: :place

  #   trait :with_search_names do
  #     after(:create) do |record|
  #       create_list(:search_name, 2, search_record: record)
  #     end
  #   end
  # end

  # factory :search_name do
  #   first_name { "John" }
  #   last_name { "Doe" }
  #   type { "primary" }
  #   # search_record
  #   association :search_record, factory: :search_record
  # end

  # factory :batch_error do
  #   sequence(:error_message) { |n| "Error message #{n}" }
  #   # freereg1_csv_file
  #   association :freereg1_csv_file, factory: :freereg1_csv_file
  # end

  # factory :embargo_rule do
  #   # register
  #   association :register, factory: :register

  #   trait :active do
  #     # Add embargo-specific fields as needed
  #   end
  # end

  # factory :gap do
  #   # register
  #   association :register, factory: :register

  #   trait :with_dates do
  #     # Add gap-specific date fields as needed
  #   end
  # end

  # factory :multiple_witness do
  #   first_name { "Jane" }
  #   last_name { "Smith" }
  #   # freereg1_csv_entry
  #   association :freereg1_csv_entry, factory: :freereg1_csv_entry
  # end

  # factory :userid_detail do
  #   sequence(:userid) { |n| "volunteer_#{n}" }
  #   sequence(:email_address) { |n| "user#{n}@example.com" }
  #   person_forename { "Test" }
  #   person_surname { "User" }
  #   syndicate { "Transcripber"}

  #   trait :with_csv_files do
  #     after(:create) do |user|
  #       create_list(:freereg1_csv_file, 3, userid_detail: user)
  #     end
  #   end

  #   trait :with_assignments do
  #     after(:create) do |user|
  #       create_list(:assignment, 2, userid_detail: user)
  #     end
  #   end
  # end

  # factory :church_name do
  #   sequence(:name) { |n| "Church#{n}" }
  #   sequence(:toponym_id) { |n| n }
  # end

  # factory :search_query do
  #   first_name { "John" }
  #   last_name { "Smith" }
  #   start_year { 1850 }
  #   end_year { 1900 }

  #   trait :with_places do
  #     after(:create) do |query|
  #       query.places = create_list(:place, 2)
  #       query.save
  #     end
  #   end

  #   trait :with_search_result do
  #     after(:create) do |query|
  #       create(:search_result, search_query: query)
  #     end
  #   end
  # end

  # factory :search_result do
  #   result_count { 100 }
  #   search_query

  #   trait :with_records do
  #     # Add result-specific fields as needed
  #   end
  # end

  # factory :embargo_record do
  #   # freereg1_csv_entry
  #   association :freereg1_csv_entry, factory: :freereg1_csv_entry
  # end

  # factory :assignment do
  #   userid_detail
  #   association :userid_detail, factory: :userid_detail
  #   # source
  #   association :source, factory: :source

  #   trait :with_images do
  #     after(:create) do |assignment|
  #       create_list(:image_server_image, 3, assignment: assignment)
  #     end
  #   end
  # end

  # factory :source do
  #   sequence(:name) { |n| "Source#{n}" }
  #   # register
  #   association :register, factory: :register

  #   trait :with_image_groups do
  #     after(:create) do |source|
  #       create_list(:image_server_group, 2, source: source)
  #     end
  #   end
  # end

  # factory :image_server_group do
  #   sequence(:name) { |n| "ImageGroup#{n}" }
  #   # source
  #   association :source, factory: :source
  #   place { nil }
  #   church { nil }

  #   trait :with_images do
  #     after(:create) do |group|
  #       create_list(:image_server_image, 5, image_server_group: group)
  #     end
  #   end
  # end

  # factory :image_server_image do
  #   sequence(:image_id) { |n| "img_#{n}" }
  #   # image_server_group
  #   association :image_server_group, factory: :image_server_group
  #   assignment { nil }
  # end

  # factory :annotation do
  #   sequence(:annotation_text) { |n| "Annotation #{n}" }
  #   # transcription
  #   association :transcription, factory: :transcription
  #   entity { nil }
  # end

  # factory :transcription do
  #   sequence(:text) { |n| "Transcribed text #{n}" }
  #   # asset
  #   association :asset, factory: :asset
  # end

  # factory :asset do
  #   sequence(:name) { |n| "Asset#{n}" }
  #   # asset_collection
  #   association :asset_collection, factory: :asset_collection
  # end

  # factory :asset_collection do
  #   sequence(:name) { |n| "Collection#{n}" }
  # end

  # factory :unique_name do
  #   sequence(:name) { |n| "UniqueName#{n}" }
  #   # place
  #   association :place, factory: :place
  # end

  # factory :place_unique_name do
  #   sequence(:name) { |n| "PlaceUniqueName#{n}" }
  #   # place
  #   association :place, factory: :place
  # end

  # factory :alternateplacename do
  #   sequence(:name) { |n| "AltPlace#{n}" }
  #   # place
  #   association :place, factory: :place
  # end

  # factory :county do
  #   sequence(:name) { |n| "County#{n}" }

  #   trait :with_districts do
  #     after(:create) do |county|
  #       create_list(:freecen2_district, 2, county: county)
  #     end
  #   end
  # end

end
