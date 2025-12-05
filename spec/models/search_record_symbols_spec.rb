require 'rails_helper'

RSpec.describe SearchRecord, type: :model do
  describe "#name_contains_symbols?" do
    let(:record) { build(:search_record, :with_symbols_in_names) }

    it "returns true when name contains a hyphen" do
      expect(record.name_contains_symbols?("Anne-Marie")).to eq(true)
    end

    it "returns true when name contains an apostrophe" do
      expect(record.name_contains_symbols?("O'Connor")).to eq(true)
    end

    it "returns false when name has no symbols" do
      expect(record.name_contains_symbols?("Smith")).to eq(false)
    end

    it "returns false for blank string" do
      expect(record.name_contains_symbols?("")).to eq(false)
    end

    it "returns false for nil input" do
      expect(record.name_contains_symbols?(nil)).to eq(false) 
    end
  end

  describe "#clean_name" do
    let(:record) { build(:search_record, :with_symbols_in_names) }

    it "removes hyphens from names" do
      expect(record.clean_name("Anne-Marie")).to eq("AnneMarie")
    end

    it "removes apostrophes from names" do
      expect(record.clean_name("O'Connor")).to eq("OConnor")
    end

    it "removes multiple symbols" do
      expect(record.clean_name("Robert \"Bob\" Jones; Sr.")).to eq("Robert Bob Jones Sr")
    end

    it "returns unchanged string if no symbols present" do
      expect(record.clean_name("Smith")).to eq("Smith")
    end

    it "returns empty string if input is empty" do
      expect(record.clean_name("")).to eq("")
    end

    it "returns nil if input is nil" do
      expect(record.clean_name(nil)).to eq(nil)
    end
  end
end
