FactoryBot.define do
  factory :freereg1_csv_entry do
    church_name           { "St Mary" }
    county                { "NFK" }
    file_line_number      { 1 }
    register_type         { "baptism" }
    record_type           { RecordType::ALL_FREEREG_TYPES.first }  # ensure valid
    place                 { "Norfolk" }
    register_entry_number { "001" }
    association :freereg1_csv_file
  end
end
