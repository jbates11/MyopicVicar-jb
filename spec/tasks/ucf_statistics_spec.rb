require "rails_helper"
require "rake"

RSpec.describe "ucf:ucf_statistics", type: :task do
  before do
    Rake::Task.clear
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task["ucf:ucf_statistics"] }

  def run_task
    capture_stdout { task.invoke }
  ensure
    task.reenable
  end

  # Helper to capture STDOUT
  def capture_stdout
    original_stdout = $stdout
    fake = StringIO.new
    $stdout = fake
    yield
    fake.string
  ensure
    $stdout = original_stdout
  end

  context "when no places have UCF data" do
    it "reports zero counts" do
      output = run_task
      json = JSON.parse(output)

      expect(json["total_places_with_ucf"]).to eq(0)
      expect(json["total_ucf_records"]).to eq(0)
      expect(json["total_ucf_files"]).to eq(0)
      expect(json["largest_ucf_lists"]).to eq([])
    end
  end

  context "when places have UCF data" do
    let!(:place1) { create(:place, :with_ucf_data, record_count: 5, file_count: 2) }
    let!(:place2) { create(:place, :with_ucf_data, record_count: 3, file_count: 1) }

    it "aggregates totals correctly" do
      json = JSON.parse(run_task)

      expect(json["total_places_with_ucf"]).to eq(2)
      expect(json["total_ucf_records"]).to eq(8)
      expect(json["total_ucf_files"]).to eq(3)
    end

    it "includes per-place stats" do
      json = JSON.parse(run_task)
      list = json["largest_ucf_lists"]

      expect(list.size).to eq(2)

      entry = list.find { |e| e["place"].include?(place1.place_name) }
      expect(entry["records"]).to eq(5)
      expect(entry["files"]).to eq(2)
    end

    it "sorts by record count descending" do
      json = JSON.parse(run_task)
      list = json["largest_ucf_lists"]

      expect(list.first["records"]).to eq(5)
      expect(list.last["records"]).to eq(3)
    end
  end

  #  JC pending
  context "when data is malformed" do
    let!(:place_bad) do
      create(:place, ucf_list: nil)
    end

    it "does not crash and treats nils safely" do
      expect { run_task }.not_to raise_error
    end
  end

end
