require 'rails_helper'

RSpec.describe Place, type: :model do
  it 'traces from Place down to its Freereg1CsvFile' do
    place    = create(:place, place_name: "York")
    church   = create(:church, place: place, church_name: "St Mary")
    register = create(:register, church: church, register_name: "Baptism Register")
    file     = create(:freereg1_csv_file, register: register, file_name: "york_baptisms.csv")

    # Trace the associations
    puts "Church:\n#{place.churches.first.ai}"
    expect(place.churches.first).to eq(church)
    
    puts "Register:\n#{church.registers.first.ai}"
    # ap church.registers.first
    expect(church.registers.first).to eq(register)

    puts 'File:'
    mongoid_ap register.freereg1_csv_files.first
    expect(register.freereg1_csv_files.first).to eq(file)

    # Direct trace from place to file
    traced_file = place.churches.first.registers.first.freereg1_csv_files.first
    puts 'traced_file:'
    mongoid_ap traced_file
    expect(traced_file.file_name).to eq("york_baptisms.csv")
  end
end
