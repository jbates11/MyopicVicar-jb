require 'mongo'
require 'bson'

namespace :mongo do
  desc "Scan all collections in a remote MongoDB database for a specific _id.
        Usage:
          rake mongo:scan_remote_id ID=695d76f6892d3be924f241af
          rake mongo:scan_remote_id ID=691b73b49dd9bf505bbe6a61 DB=myopic_vicar_production MONGO_URI=mongodb://user:pass@remote-host:27017"

  task :scan_remote_id do
    id_str   = ENV['ID'] || abort("ERROR: ID parameter required. Usage: rake mongo:scan_remote_id ID=<id_string>")
    db_name  = ENV['DB'] || 'myopic_vicar_development'
    uri      = ENV['MONGO_URI'] || 'mongodb://mongo:27017'

    begin
      target_id = BSON::ObjectId.from_string(id_str)
    rescue => e
      puts "ERROR: Invalid BSON::ObjectId format: #{id_str}"
      puts "Details: #{e.message}"
      exit 1
    end

    client = nil
    begin
      puts "Connecting to MongoDB at #{uri.gsub(/\/\/.*@/, '//***:***@')}..."
      client = Mongo::Client.new(uri, database: db_name)
      
      collections = if client.database.respond_to?(:collection_names)
                      client.database.collection_names
                    else
                      client.database.collections.map(&:name)
                    end

      puts "Connected. Scanning #{collections.size} collections in '#{db_name}' for _id=#{id_str}...\n\n"

      found_count = 0
      collections.each do |coll_name|
        coll = client[coll_name]
        doc = coll.find(_id: target_id).first

        if doc
          found_count += 1
          puts "-" * 80
          puts "✓ Found in collection: #{coll_name}"
          puts "-" * 80
          # ap doc
          pp doc
          puts
        end
      end

      puts "-" * 80
      if found_count > 0
        puts "✓ Scan complete. Found in #{found_count} collection(s)."
      else
        puts "✗ Scan complete. No document found with _id=#{id_str}."
      end
      puts "-" * 80
    rescue Mongo::Error::NoServerAvailable => e
      puts "ERROR: Could not connect to MongoDB at #{uri}"
      puts "Ensure the server is reachable and credentials are correct."
      puts "Details: #{e.message}"
      exit 1
    rescue => e
      puts "ERROR: #{e.class}: #{e.message}"
      puts e.backtrace.first(10).join("\n")
      exit 1
    ensure
      client&.close
    end
  end
end
