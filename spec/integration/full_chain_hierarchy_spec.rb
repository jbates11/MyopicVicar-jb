require 'rails_helper'

RSpec.describe "Full hierarchy integration", type: :model do
  it "creates and navigates the full chain from Place down to SearchName" do
    # Step 1: Place
    place = create(:place, place_name: "Norfolk", chapman_code: "NFK")

    # Step 2: Church
    church = create(:church, place: place, church_name: "St Mary")

    # Step 3: Register
    register = create(:register, church: church, register_name: "Baptism Register", register_type: "baptism")

    # Step 4: UseridDetail
    # user = create(:userid_detail, userid: "jdoe", person_forename: "John", person_surname: "Doe",
                                  # syndicate: "Norfolk", email_address: "jdoe@example.com")

    # Step 5: Freereg1CsvFile
    # file = create(:freereg1_csv_file, register: register, userid_detail: user,
    file = create(:freereg1_csv_file, register: register,
                                     file_name: "baptisms.csv", county: "NFK", record_type: RecordType::ALL_FREEREG_TYPES.first)

    # Step 6: Freereg1CsvEntry
    entry = create(:freereg1_csv_entry, freereg1_csv_file: file,
                                       church_name: "St Mary", county: "NFK", file_line_number: 1)

    # Step 7: SearchRecord
    record = create(:search_record, freereg1_csv_entry: entry, place: place,
                                    transcript_names: ["John Doe"], transcript_dates: ["1801-01-01"])

    # Step 8: SearchName (embedded)
    record.search_names << build(:search_name, first_name: "John", last_name: "Doe", role: "child", gender: "m", type: "primary")
    record.save!

    # ✅ Assertions: Navigate the full chain
    expect(record.search_names.first.first_name).to eq("John")
    expect(record.place.place_name).to eq("Norfolk")
    expect(entry.freereg1_csv_file.register.church.place).to eq(place)
    # expect(file.userid_detail.userid).to eq("jdoe")
  end
end
