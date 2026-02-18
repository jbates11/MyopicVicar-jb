require 'rails_helper'

RSpec.describe SearchRecord, type: :model do
  describe "#contains_wildcard_ucf" do
    context "when no names contain wildcards" do
      it "returns nil" do
        record = build(:search_record,
                       search_names: [build(:search_name, first_name: "Jimmmy", last_name: "Rack")])
        expect(record.contains_wildcard_ucf).to be_nil
      end
    end

    context "when first_name contains a wildcard" do
      it "returns the flagged SearchName" do
        record = build(:search_record,
                       search_names: [build(:search_name, first_name: "Jo*n", last_name: "Doe")])
        flagged = record.contains_wildcard_ucf
        expect(flagged).to be_a(SearchName)
        expect(flagged.first_name).to eq("Jo*n")
      end
    end

    context "when last_name contains a wildcard" do
      it "returns the flagged SearchName" do
        record = build(:search_record,
                       search_names: [build(:search_name, first_name: "John", last_name: "Do_e")])
        flagged = record.contains_wildcard_ucf
        expect(flagged).to be_a(SearchName)
        expect(flagged.last_name).to eq("Do_e")
      end
    end

    context "when multiple names are present" do
      it "returns the first flagged SearchName" do
        record = build(:search_record,
                       search_names: [
                         build(:search_name, first_name: "Jack", last_name: "Black"),
                         build(:search_name, first_name: "Sm?th", last_name: "Brown")
                       ])
        flagged = record.contains_wildcard_ucf
        expect(flagged.first_name).to eq("Sm?th")
      end
    end
  end
end
