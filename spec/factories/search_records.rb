FactoryBot.define do
  factory :search_record do
    asset_id         { "asset_123" }
    chapman_code     { "NFK" }
    birth_place      { "Norfolk" }
    transcript_names { ["John Doe"] }
    transcript_dates { ["1801-01-01"] }
    association :freereg1_csv_entry
    association :place

    # Build embedded SearchName inside SearchRecord
    after(:build) do |record|
      record.search_names << build(:search_name, search_record: record)
    end
  end
end
