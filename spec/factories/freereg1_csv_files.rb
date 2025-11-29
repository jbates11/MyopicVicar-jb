FactoryBot.define do
  factory :freereg1_csv_file do
    file_name     { "baptisms.csv" }
    county        { "NFK" }
    chapman_code  { "NFK" }
    church_name   { "St Mary" }
    register_type { "baptism" }
    record_type   { RecordType::ALL_FREEREG_TYPES.first }  # ensure valid
    place_name    { "Norfolk" }
    userid        { "jdoe" }
    association :register
    # association :userid_detail
  end
end
