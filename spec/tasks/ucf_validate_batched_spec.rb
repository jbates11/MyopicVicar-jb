require "rails_helper"

RSpec.describe "ucf:validate_ucf_lists (batched refactor)", type: :task do
  include RakeHelper

  let!(:place) { create(:place, ucf_list: ucf_list) }

  context "batch behavior" do
    let(:file1) { create(:freereg1_csv_file) }
    let(:file2) { create(:freereg1_csv_file) }
    let(:record1) { create(:search_record) }

    let(:ucf_list) do
      {
        file1.id.to_s => [record1.id.to_s, "missing_record"],
        "missing_file" => []
      }
    end

    it "removes missing file IDs and missing record IDs in one pass" do
      run_rake("ucf:validate_ucf_lists", 10, "fix")

      fresh_place = Place.where(id: place.id).first

      expect(fresh_place.ucf_list.keys).to contain_exactly(file1.id.to_s)
      expect(fresh_place.ucf_list[file1.id.to_s]).to contain_exactly(record1.id.to_s)
    end
  end

  context "location mismatch" do
    let(:file) { create(:freereg1_csv_file, chapman_code: "NFK") }
    let(:ucf_list) { { file.id.to_s => [] } }

    it "reports mismatch but does not modify ucf_list" do
      run_rake("ucf:validate_ucf_lists", 10, nil)

      fresh_place = Place.where(id: place.id).first
      expect(fresh_place.ucf_list.keys).to include(file.id.to_s)
    end
  end
end
