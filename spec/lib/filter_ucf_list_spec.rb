require 'rails_helper'
require 'filter_ucf_list'

RSpec.describe FilterUcfList, type: :model do
  # Dummy Mongoid model for testing
  # This simulates a collection with "first_name" and "last_name" fields
  class DummyModel
    include Mongoid::Document
    field :first_name, type: String
    field :last_name, type: String
    field :church_name, type: String
    field :ucf_list, type:Array
  end

  let(:output_dir) { Rails.root.join("tmp/filter_ucf_test/") }
  let(:filter) { described_class.new(DummyModel, output_dir.to_s) }

  before do
    FileUtils.mkdir_p(output_dir)

    # Clean up any old files before each test
    Dir.glob("#{output_dir}/*").each { |f| File.delete(f) }

    # Seed test data
    DummyModel.delete_all
    DummyModel.create!(first_name: "Alice", last_name: "Smith")
    DummyModel.create!(first_name: "Bob?", last_name: "Jones")
    DummyModel.create!(first_name: "Carol*", last_name: "Brown")
    DummyModel.create!(first_name: "David", last_name: "_Taylor")
    DummyModel.create!(first_name: "Edward_", last_name: "King")
    DummyModel.create!(first_name: "Fr_nk", last_name: "Green_")
  end

  after do
    # Clean up after tests
    FileUtils.rm_rf(output_dir)
  end

   describe "#initialize" do
    it "raises ArgumentError if model_name is nil" do
      expect { described_class.new(nil, output_dir.to_s) }.to raise_error(ArgumentError)
    end

    it "sets model_name and output_directory" do
      expect(filter.model_name).to eq(DummyModel)
      expect(filter.output_directory).to eq(output_dir.to_s)
    end
  end

  describe "#fetch_columns" do
    it "returns all attribute names from the model" do
      p filter.send(:fetch_columns)
      expect(filter.send(:fetch_columns)).to include("first_name", "last_name", "church_name")
    end
  end

  describe "#retrieve_name_columns" do
    it "returns only columns containing 'name'" do
      p filter.send(:retrieve_name_columns)
      expect(filter.send(:retrieve_name_columns)).to match_array(["first_name", "last_name", "church_name"])
    end
  end

  describe "#special_character_records" do
    it "finds records with special characters in first_name" do
      results = filter.send(:special_character_records, "first_name")
      # p results
      p results.map(&:first_name)
      expect(results.map(&:first_name)).to include("Bob?", "Carol*")
    end

    it "returns empty if no records match" do
      results = filter.send(:special_character_records, "church_name")
      expect(results).to be_empty
    end
  end

  describe "#valid_directory?" do
    it "returns true if directory exists" do
      expect(filter.send(:valid_directory?)).to be true
    end

    it "returns false if directory does not exist" do
      bad_filter = described_class.new(DummyModel, "/not/a/real/path/")
      expect(bad_filter.send(:valid_directory?)).to be false
    end
  end

  describe "#new_file" do
    it "creates a timestamped file path" do
      file_path = filter.send(:new_file, "first_name")
      expect(file_path).to include("first_name.txt")
    end

    it "raises error if directory is invalid" do
      bad_filter = described_class.new(DummyModel, "/not/a/real/path/")
      expect { bad_filter.send(:new_file, "first_name") }.to raise_error("Not a Valid Directory")
    end
  end

  describe "#filter_id" do
    it "writes IDs of records with special characters into files" do
      filter.filter_id
      files = Dir.glob("#{output_dir}/*first_name.txt")
      expect(files).not_to be_empty

      content = File.read(files.first)
      expect(content).to include(DummyModel.where(first_name: "Bob?").first.id.to_s)
      expect(content).to include(DummyModel.where(first_name: "Carol*").first.id.to_s)
    end

    it "creates merged and unique files" do
      filter.filter_id
      expect(File).to exist("#{output_dir}/single_ucf_file_lists.txt")
      expect(File).to exist("#{output_dir}/unique_ucf_lists.txt")

      unique_ids = File.readlines("#{output_dir}/unique_ucf_lists.txt").map(&:strip)
      expect(unique_ids).to match_array(unique_ids.uniq) # no duplicates
    end
  end
end
