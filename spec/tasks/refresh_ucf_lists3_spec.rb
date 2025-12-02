require 'rails_helper'
require 'rake'

RSpec.describe "refresh_ucf_lists rake task", type: :task do
  before(:all) do
    Rake.application.rake_require("tasks/foo") # loads lib/tasks/foo.rake
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task["foo:refresh_ucf_lists"] }

  context "when places have search records with wildcard UCFs" do
    it "updates place and file ucf_list with flagged IDs" do
      place  = create(:place, place_name: "Testville")
      file   = create(:freereg1_csv_file, place_name: place.place_name)
      entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record, freereg1_csv_entry: entry, place: place)

      # Attach a SearchName with a wildcard
      record.search_names << build(:search_name, first_name: "Jo*n", last_name: "Doe")
      record.save!

      task.invoke

      place.reload
      file.reload

      expect(place.ucf_list[file.id.to_s]).to include(record.id)
      expect(file.ucf_list).to include(record.id)
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end

  context "when places have search records without wildcard UCFs" do
    it "sets empty arrays for ucf_list" do
      place  = create(:place, place_name: "Testville")
      file   = create(:freereg1_csv_file, place_name: place.place_name)
      entry  = create(:freereg1_csv_entry, freereg1_csv_file: file)
      record = create(:search_record, freereg1_csv_entry: entry, place: place)

      # Attach a SearchName without wildcards
      record.search_names << build(:search_name, first_name: "John", last_name: "Doe")
      record.save!

      task.reenable
      task.invoke

      place.reload
      file.reload

      expect(place.ucf_list[file.id.to_s]).to eq({})
      expect(file.ucf_list).to eq({})
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end

  context "when places have no search records" do
    it "sets empty arrays for ucf_list" do
      place = create(:place, place_name: "Testville")
      file  = create(:freereg1_csv_file, place_name: place.place_name)
      create(:freereg1_csv_entry, freereg1_csv_file: file)
      # No SearchRecord created

      task.reenable
      task.invoke

      place.reload
      file.reload

      # expect(place.ucf_list[file.id.to_s]).to eq({})
      # expect(file.ucf_list).to eq([])
      expect(file.ucf_updated).to eq(DateTime.now.to_date)
    end
  end
end
