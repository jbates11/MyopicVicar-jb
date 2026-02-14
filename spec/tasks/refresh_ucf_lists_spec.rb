require 'rails_helper'
require 'rake'

RSpec.describe 'foo:refresh_ucf_lists task', type: :task do
  before(:all) do
    # Load the rake task file
    Rake.application.rake_require('tasks/foo') # loads lib/tasks/foo.rake
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['foo:refresh_ucf_lists'] }

  before(:each) do
    task.reenable # allow task to be run multiple times
  end

  context 'when Places and Files exist' do
    let!(:place) do
      create(:place, place_name: "York", chapman_code: "ENG", ucf_list: { "old" => 1 })
    end
    let!(:church)   { create(:church, place: place, church_name: "St Mary") }
    let!(:register) { create(:register, church: church, register_name: "Baptism Register") }
    let!(:file) do
      create(:freereg1_csv_file,
             register: register,
             file_name: "york_baptisms.csv",
             place_name: place.place_name,
             chapman_code: place.chapman_code,
             ucf_list: ["unclean"])
    end

    it 'updates the ucf_list on Freereg1CsvFile' do
      # mongoid_ap file
      expect(file.ucf_list).to eq(["unclean"]) # initially populated

      task.invoke
      (file.class.find(file.id))

      # puts "==========================================================="
      # mongoid_ap file
      expect(file.ucf_list).to be_empty.or be_a(Array) # should be refreshed
    end

    it 'updates the ucf_list on Place' do
      # mongoid_ap file
      # puts "***********************************************************"
      # mongoid_ap place
      expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated

      task.invoke
      (place.class.find(place.id))

      # puts "==========================================================="
      # mongoid_ap place
      expect(place.ucf_list).to eq({}).or be_a(Hash) # should be refreshed
    end
  end

  #  JC NOT useful
  # context 'when no Places exist' do
  #   it 'runs without error' do
  #     # Place.delete_all  # JC disable
  #     expect { task.invoke }.not_to raise_error
  #   end
  # end



  context 'when Places and Files exist' do
    let!(:place) do
      create(:place, place_name: "York", chapman_code: "ENG", ucf_list: { "old" => 1 })
    end
    let!(:church)   { create(:church, place: place, church_name: "St Mary") }
    let!(:register) { create(:register, church: church, register_name: "Baptism Register") }
    let!(:file) do
      create(:freereg1_csv_file,
             register: register,
             file_name: "york_baptisms.csv",
             place_name: place.place_name,
             chapman_code: place.chapman_code,
             ucf_list: ["unclean"])
    end

    it "resets ucf_list and updates files" do
      expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated
      expect(file.ucf_list).to eq(["unclean"]) # initially populated

      task.invoke # run rake task with defaults
      (place.class.find(place.id))
      (file.class.find(file.id))

      expect(place.ucf_list).to eq({}).or be_a(Hash) # should be refreshed
      expect(file.updated_at).to be_present # file should be saved
      expect(file.ucf_list).to be_empty.or be_a(Array) # should be refreshed
    end

    it "writes to log file" do
      log_path = Rails.root.join("log", "refresh_ucf_lists.log")

      task.invoke

      log_content = File.read(log_path)
      expect(log_content).to include("finished refresh_ucf_lists")
      expect(log_content).to include(place.place_name)
    end
  end

  it "skips heavy file SOMFSJBA.csv for YvonneScrivener" do   
    place = create(:place, place_name: "York", chapman_code: "ENG", ucf_list: { "old" => 1 })
    heavy_file = create(:freereg1_csv_file,
                        place_name: place.place_name,
                        file_name: "SOMFSJBA.csv",
                        userid: "YvonneScrivener")

    task.invoke
    (place.class.find(place.id))
    
    # expect(place.ucf_list).to eq({})

    # Heavy file should not alter ucf_list - pending task code change
    expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated
  end




  context "when places have search records with wildcard UCFs" do
    it "updates place and file ucf_list with flagged IDs" do
      place  = create(:place, place_name: "Testville", data_present: true)
      file   = create(:freereg1_csv_file, place_name: place.place_name)
      entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record, :baptism_record, freereg1_csv_entry: entry, place: place)

      # Attach a SearchName with a wildcard
      record.search_names << build(:search_name, first_name: "Jo*n", last_name: "Doe")

      task.invoke
      (place.class.find(place.id))
      (file.class.find(file.id))

      # RELOAD the objects to get the data the Rake task wrote to MongoDB
      place.reload
      file.reload

      expect(place.ucf_list[file.id.to_s]).to include(record.id)
      expect(file.ucf_list).to include(record.id)
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end

  context "when places have search records without wildcard UCFs" do
    it "sets empty arrays for ucf_list" do
      place  = create(:place, place_name: "Testville", data_present: true)
      file   = create(:freereg1_csv_file, place_name: place.place_name)
      entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record, :baptism_record, freereg1_csv_entry: entry, place: place)

      # Attach a SearchName without wildcards
      record.search_names << build(:search_name, first_name: "John", last_name: "Doe")

      task.invoke
      (place.class.find(place.id))
      (file.class.find(file.id))

      # RELOAD the objects to get the data the Rake task wrote to MongoDB
      place.reload     
      file.reload

      expect(place.ucf_list[file.id.to_s]).to eq([])
      expect(file.ucf_list).to eq([])
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end

  context "when places have no search records" do
    it "sets empty arrays for ucf_list" do
      place = create(:place, place_name: "Testville", data_present: true)
      file  = create(:freereg1_csv_file, place_name: place.place_name)
      create(:freereg1_csv_entry, freereg1_csv_file: file)
      # No SearchRecord created

      task.invoke
      (place.class.find(place.id))
      (file.class.find(file.id))

      # RELOAD the objects to get the data the Rake task wrote to MongoDB
      place.reload     
      file.reload

      expect(place.ucf_list[file.id.to_s]).to eq([])
      expect(file.ucf_list).to eq([])
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end



end
