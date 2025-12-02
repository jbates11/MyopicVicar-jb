# The `FilterUcfList` class is designed to:
# - Scan a Mongoid model (MongoDB collection) for columns/fields containing “name”.
# - Find records where those name fields contain special characters (_ ? * { } [ ]).
# - Write the IDs of those records into text files for auditing.
# - Merge all those files into one combined list.
# - Deduplicate entries into a final clean file.
# 
class FilterUcfList
  attr_reader :model_name, :output_directory
  # JC model_name = Freereg1CsvEntry

  # Rules to filter the special characters
  SPECIAL_CHARACTER_LISTS = /[_?*{}\[\]]/

  def initialize(model_name, output_directory = nil)
    raise ArgumentError, "Model name can't be blank" if model_name.nil?

    @model_name = model_name
    @output_directory = output_directory || File.join(Rails.root, 'script')

    Rails.logger.debug { "Initialized FilterUcfList with model=#{model_name}, output_directory=#{@output_directory}" }
    # p self
  end

  # Main entry point: filter IDs with special characters
  def filter_id
    Rails.logger.info "Starting filter_id process..."
    p "Starting filter_id process..."

    retrieve_name_columns.each do |name|
      next if name == "church_name"

      Rails.logger.debug { "Processing column: #{name}" }
      p "Processing column: #{name}"

      begin
        file_path = new_file(name)
        Rails.logger.debug { "Writing IDs to #{file_path}" }

        File.open(file_path, "w") do |file|
          special_character_records(name).each do |record|
            file.puts record.id
          end
        end

        count = special_character_records(name).count
        Rails.logger.info "Total number of ids for #{name}: #{count}"
        p "Total number of ids for #{name}: #{count}"
      rescue => e
        Rails.logger.error "Error processing column #{name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        p "Error processing column #{name}: #{e.message}"
      end
    end

    single_ucf_file_lists
    remove_duplicate_entries

    Rails.logger.info "filter_id process finished"
    p "filter_id process finished"
  end

  private

  # Fetch all the column/field attribute names from the table
  def fetch_columns
    model_name.attribute_names
  end

  # Retrieve the column/field attributes containing 'name'
  def retrieve_name_columns
    fetch_columns.grep(/name/)
  end

  # Retrieve the special character records from the model
  def special_character_records(column_name)
    model_name.where(column_name.to_sym => SPECIAL_CHARACTER_LISTS)
  end

  # Validate the directory exists
  def valid_directory?
    File.directory?(output_directory_path)
  end

  # Create a new file named with current date and time
  def new_file(name)
    raise "Not a Valid Directory" unless valid_directory?

    file_name = "#{Time.now.strftime("%Y%m%d%H%M%S")}_#{name}.txt"
    File.join(output_directory_path, file_name)
  end

  # Ensure trailing slash in directory path
  def output_directory_path
    File.join(@output_directory, "")
  end

  def single_ucf_file
    File.join(output_directory_path, "single_ucf_file_lists.txt")
  end

  # Merge all UCF files into a single file
  def single_ucf_file_lists
    Rails.logger.info "Merging all *name.txt files into #{single_ucf_file}"
    p "Merging files..."

    File.open(single_ucf_file, 'a') do |mergedfile|
      Dir.glob("#{output_directory_path}*name.txt").each do |file|
        Rails.logger.debug { "Merging file: #{file}" }
        File.foreach(file) { |line| mergedfile.write(line) }
      end
    end
  end

  # Remove duplicate entries from the merged text file
  def remove_duplicate_entries
    unique_file = File.join(output_directory_path, "unique_ucf_lists.txt")
    Rails.logger.info "Removing duplicates into #{unique_file}"
    p "Removing duplicates..."

    File.open(unique_file, "w+") do |file|
      file.puts File.readlines(single_ucf_file).uniq
    end
  end
end
