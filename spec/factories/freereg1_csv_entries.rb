FactoryBot.define do
  factory :freereg1_csv_entry do
    sequence(:file_line_number) { |n| n }
    church_name { 'St. Mary' }
    county { 'SUR' }
    # file_line_number { 1 }
    place { 'Guildford' }
    register_entry_number { '001' }
    register_type { 'Baptism' }
    record_type { RecordType::BAPTISM }

    association :freereg1_csv_file, factory: :freereg1_csv_file
    # association :search_record, factory: :search_record
    # freereg1_csv_file # Shortened syntax
    # search_record     # Shortened syntax

    # Baptism-specific traits
    trait :baptism do
      record_type { RecordType::BAPTISM }
      person_forename { 'John' }
      person_surname { 'Smith' }
      person_sex { 'm' }
      father_forename { 'Thomas' }
      father_surname { 'Smith' }
      mother_forename { 'Mary' }
      mother_surname { 'Jones' }
    end

    trait :baptism_no_person_surname do
      record_type { RecordType::BAPTISM }
      baptism_date { '01 JAN 1850' }
      person_forename { 'John' }
      person_surname { nil }
      person_sex { 'm' }
      father_forename { 'Thomas' }
      father_surname { 'Smith' }
      mother_forename { 'Mary' }
      mother_surname { 'Jones' }
    end

    trait :baptism_father_only do
      record_type { RecordType::BAPTISM }
      # baptism_date { '01 JAN 1850' }
      person_forename { 'John' }
      person_surname { nil }
      person_sex { 'm' }
      father_forename { 'Thomas' }
      father_surname { 'Smith' }
      mother_forename { nil }
      mother_surname { nil }
    end

    trait :baptism_mother_only do
      record_type { RecordType::BAPTISM }
      # baptism_date { '01 JAN 1850' }
      person_forename { 'John' }
      person_surname { nil }
      person_sex { 'm' }
      father_forename { nil }
      father_surname { nil }
      mother_forename { 'Mary' }
      mother_surname { 'Jones' }
    end

    trait :baptism_both_parents do
      record_type { RecordType::BAPTISM }
      # baptism_date { '01 JAN 1850' }
      person_forename { 'John' }
      person_surname { nil }
      person_sex { 'm' }
      father_forename { 'Thomas' }
      father_surname { 'Smith' }
      mother_forename { 'Mary' }
      mother_surname { 'Jones' }
    end

    trait :baptism_with_witnesses do
      record_type { RecordType::BAPTISM }
      # baptism_date { '25/01/1850' }
      # baptism_date { '01 JAN 1850' }
      # baptism_date { '01/JAN/1850' }
      # baptism_date { '1850/JAN/25' }
      # baptism_date { '1850/01/25' }
      # baptism_date { '18*' } # JC this works
      # baptism_date { '1850' } # JC this works
      baptism_date { '185*' } # JC this works
      person_forename { 'John' }
      person_surname { 'Smith' }
      father_forename { 'Thomas' }
      father_surname { 'Smith' }
      mother_forename { 'Mary' }
      mother_surname { 'Jones' }

      after(:build) do |entry|
        entry.multiple_witnesses = [
          build(:multiple_witness, witness_forename: 'Jane', witness_surname: 'Brown'),
          build(:multiple_witness, witness_forename: 'Robert', witness_surname: 'Green')
        ]
      end
    end

    # Burial-specific traits
    trait :burial do
      record_type { RecordType::BURIAL }
      # burial_date { '15 JAN 1850' }
      burial_person_forename { 'William' }
      burial_person_surname { 'Johnson' }
      female_relative_forename { 'Sarah' }
      female_relative_surname { 'Smith' }
      male_relative_forename { 'George' }
      relative_surname { 'Johnson' }
    end

    trait :burial_no_surname do
      record_type { RecordType::BURIAL }
      # burial_date { '15 JAN 1850' }
      burial_person_forename { 'William' }
      burial_person_surname { nil }
      relative_surname { 'Johnson' }
      female_relative_surname { nil }
    end

    trait :burial_with_relatives do
      record_type { RecordType::BURIAL }
      burial_date { '15 JAN 1850' }
      burial_person_forename { 'William' }
      burial_person_surname { 'Johnson' }
      female_relative_forename { 'Sarah' }
      female_relative_surname { 'Smith' }
      male_relative_forename { 'George' }
      relative_surname { 'Johnson' }
    end

    # Marriage-specific traits
    trait :marriage do
      record_type { RecordType::MARRIAGE }
      # marriage_date { '25 JAN 1850' }
      bride_forename { 'Elizabeth' }
      bride_surname { 'Brown' }
      groom_forename { 'John' }
      groom_surname { 'Smith' }
      bride_father_forename { 'Robert' }
      bride_father_surname { 'Brown' }
      groom_father_forename { 'Thomas' }
      groom_father_surname { 'Smith' }
    end

    trait :marriage_with_all_parents do
      record_type { RecordType::MARRIAGE }
      marriage_date { '25 JAN 1850' }
      bride_forename { 'Elizabeth' }
      bride_surname { 'Brown' }
      groom_forename { 'John' }
      groom_surname { 'Smith' }
      bride_father_forename { 'Robert' }
      bride_father_surname { 'Brown' }
      bride_mother_forename { 'Anne' }
      bride_mother_surname { 'White' }
      groom_father_forename { 'Thomas' }
      groom_father_surname { 'Smith' }
      groom_mother_forename { 'Jane' }
      groom_mother_surname { 'Davis' }
    end

    trait :marriage_with_witnesses do
      record_type { RecordType::MARRIAGE }
      marriage_date { '25 JAN 1850' }
      bride_forename { 'Elizabeth' }
      bride_surname { 'Brown' }
      groom_forename { 'John' }
      groom_surname { 'Smith' }

      after(:build) do |entry|
        entry.multiple_witnesses = [
          build(:multiple_witness, witness_forename: 'James', witness_surname: 'Davis')
        ]
      end
    end
  end

  factory :multiple_witness do
    witness_forename { 'John' }
    witness_surname { 'Witness' }

    to_create { |instance| instance }
  end
end
