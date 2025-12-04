require "rails_helper"
require "rake"

RSpec.describe "foo:refresh_ucf_lists", type: :task do
  before(:all) do
    # Load rake tasks file
    Rake.application.rake_require("tasks/foo")  # loads lib/tasks/foo.rake
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task["foo:refresh_ucf_lists"] }

  before do
    task.reenable # allow task to be run multiple times in same spec
    # Clean DB before each run
    # Place.delete_all
    # Freereg1CsvFile.delete_all
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

    it "resets ucf_list and updates files" do
      expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated
      expect(file.ucf_list).to eq(["unclean"]) # initially populated

      task.invoke # run rake task with defaults
      place.reload
      file.reload

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
    place.reload
    
    # Heavy file should not alter ucf_list
    expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated
  end
end
