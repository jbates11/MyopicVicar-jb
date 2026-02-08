FactoryBot.define do
  factory :search_record do
    sequence(:id) { |n| "SR#{n}" }
    record_type { RecordType::BAPTISM }
    search_record_version { '1' }
    chapman_code { 'SUR' }
    search_date { '1850' }
    secondary_search_date { nil }
    transcript_dates { ['01 JAN 1850'] }
    transcript_names do
      [
        { role: 'ba', type: 'primary', first_name: 'John', last_name: 'Smith' }
      ]
    end

    association :freereg1_csv_entry, factory: :freereg1_csv_entry
    association :place, factory: :place
    
    trait :with_entry do
      freereg1_csv_entry  # Shortened syntax
      # association :freereg1_csv_entry, factory: :freereg1_csv_entry
    end

    trait :with_populated_search_names do
      after(:build) do |record|
        record.populate_search_names if record.transcript_names.present?
      end
    end

    # Baptism record traits
    trait :baptism_record do
      record_type { RecordType::BAPTISM }
      search_date { '1850' }
      transcript_names do
        [
          { role: 'ba', type: 'primary', first_name: 'John', last_name: 'Smith' },
          { role: 'f', type: 'other', first_name: 'Thomas', last_name: 'Smith' },
          { role: 'm', type: 'other', first_name: 'Mary', last_name: 'Jones' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :baptism_with_witnesses do
      record_type { RecordType::BAPTISM }
      transcript_names do
        [
          { role: 'ba', type: 'primary', first_name: 'John', last_name: 'Smith' },
          { role: 'f', type: 'other', first_name: 'Thomas', last_name: 'Smith' },
          { role: 'm', type: 'other', first_name: 'Mary', last_name: 'Jones' },
          { role: 'wt', type: 'witness', first_name: 'Jane', last_name: 'Brown' },
          { role: 'wt', type: 'witness', first_name: 'Robert', last_name: 'Green' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :baptism_no_person_surname do
      record_type { RecordType::BAPTISM }
      transcript_names do
        [
          { role: 'ba', type: 'primary', first_name: 'John', last_name: nil },
          { role: 'f', type: 'other', first_name: 'Thomas', last_name: 'Smith' },
          { role: 'm', type: 'other', first_name: 'Mary', last_name: 'Jones' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :baptism_father_surname_only do
      record_type { RecordType::BAPTISM }
      transcript_names do
        [
          { role: 'ba', type: 'primary', first_name: 'John', last_name: 'Smith' },
          { role: 'f', type: 'other', first_name: 'Thomas', last_name: 'Smith' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    # Burial record traits
    trait :burial_record do
      record_type { RecordType::BURIAL }
      search_date { '1850' }
      transcript_names do
        [
          { role: 'bu', type: 'primary', first_name: 'William', last_name: 'Johnson' },
          { role: 'fr', type: 'other', first_name: 'Sarah', last_name: 'Smith' },
          { role: 'mr', type: 'other', first_name: 'George', last_name: 'Johnson' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :burial_no_person_surname do
      record_type { RecordType::BURIAL }
      transcript_names do
        [
          { role: 'bu', type: 'primary', first_name: 'William', last_name: nil },
          { role: 'fr', type: 'other', first_name: 'Sarah', last_name: nil }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    # Marriage record traits
    trait :marriage_record do
      record_type { RecordType::MARRIAGE }
      search_date { '1850' }
      secondary_search_date { nil }
      transcript_names do
        [
          { role: 'b', type: 'primary', first_name: 'Elizabeth', last_name: 'Brown' },
          { role: 'g', type: 'primary', first_name: 'John', last_name: 'Smith' },
          { role: 'bf', type: 'other', first_name: 'Robert', last_name: 'Brown' },
          { role: 'gf', type: 'other', first_name: 'Thomas', last_name: 'Smith' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :marriage_with_all_parents do
      record_type { RecordType::MARRIAGE }
      transcript_names do
        [
          { role: 'b', type: 'primary', first_name: 'Elizabeth', last_name: 'Brown' },
          { role: 'g', type: 'primary', first_name: 'John', last_name: 'Smith' },
          { role: 'bf', type: 'other', first_name: 'Robert', last_name: 'Brown' },
          { role: 'bm', type: 'other', first_name: 'Anne', last_name: 'White' },
          { role: 'gf', type: 'other', first_name: 'Thomas', last_name: 'Smith' },
          { role: 'gm', type: 'other', first_name: 'Jane', last_name: 'Davis' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    trait :marriage_transcript_names do
      transcript_names do
        [
          { first_name: "John", last_name: "Smith", type: "primary", role: "father" },
          { first_name: "Mary", last_name: "Jones", type: "witness", role: "bridesmaid" }
        ]
      end

      # initialize search_names as an empty array
      search_names { [] }

      # optional attributes for FreeCEN context
      # freecen_csv_entry_id { nil }
      # freecen_individual { nil }
  end


    # Symbol-related traits
    trait :with_symbols_in_names do
      transcript_names do
        [
          { first_name: "Anne-Marie", last_name: "O'Connor", type: "primary", role: "father" },
          { role: 'ba', type: 'primary', first_name: "John's", last_name: 'Smith-Jones' },
          { role: 'f', type: 'other', first_name: 'Thomas.', last_name: "O'Brien" }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end

    # Downcase verification trait
    trait :with_uppercase_names do
      transcript_names do
        [
          { role: 'ba', type: 'primary', first_name: 'JOHN', last_name: 'SMITH' },
          { role: 'f', type: 'other', first_name: 'THOMAS', last_name: 'SMITH' }
        ]
      end

      after(:build) do |record|
        record.populate_search_names
      end
    end
  end
end
