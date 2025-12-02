require 'rails_helper'
require Rails.root.join('lib/ucf_transformer')

RSpec.describe SearchName, type: :model do
  describe "#contains_wildcard_ucf?" do
    context "when both names are normal" do
      it "returns false" do
        sn = build(:search_name, first_name: "John", last_name: "Doe")
        expect(sn.contains_wildcard_ucf?).to eq(false)
      end
    end

    context "when first_name contains a wildcard" do
      it "returns true" do
        sn = build(:search_name, first_name: "Jon?", last_name: "Doe")
        expect(sn.contains_wildcard_ucf?).to eq(true)
      end
    end

    context "when last_name contains a wildcard" do
      it "returns true" do
        sn = build(:search_name, first_name: "John", last_name: "Do_e")
        expect(sn.contains_wildcard_ucf?).to eq(true)
      end
    end

    context "when both names contain wildcards" do
      it "returns true" do
        sn = build(:search_name, first_name: "Sm*th", last_name: "{Jo}[hn]")
        expect(sn.contains_wildcard_ucf?).to eq(true)
      end
    end

    context "when names are blank" do
      it "returns false" do
        sn = build(:search_name, first_name: "", last_name: "")
        expect(sn.contains_wildcard_ucf?).to eq(false)
      end
    end
  end
end
