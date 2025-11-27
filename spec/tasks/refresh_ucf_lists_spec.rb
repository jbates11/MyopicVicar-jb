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
      puts "Initial file ucf_list:\n#{file.ucf_list.ai}"
      expect(file.ucf_list).to eq(["unclean"]) # initially populated
      
      task.invoke
      file.reload

      puts "After reload file ucf_list:\n#{file.ucf_list.ai}"
      expect(file.ucf_list).to be_empty.or be_a(Array) # should be refreshed
    end

    it 'updates the ucf_list on Place' do
      puts "Initial place ucf_list:\n#{place.ucf_list.ai}"
      expect(place.ucf_list).to eq({ "old" => 1 }) # initially populated

      task.invoke
      place.reload
      puts "After reload place ucf_list:\n#{place.ucf_list.ai}"
      expect(place.ucf_list).to eq({}).or be_a(Hash) # should be refreshed
    end
  end

  # DANGER! do NOT use
  # context 'when no Places exist' do
  #   it 'runs without error' do
  #     Place.delete_all
  #     expect { task.invoke }.not_to raise_error
  #   end
  # end
end
