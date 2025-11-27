# lib/tasks/scan_mongo_collections.rake
require 'mongo'
require 'bson'

namespace :mongo do
  desc "Scan all collections in a MongoDB database for a specific _id.
        Usage: rake mongo:scan_id ID=691b73b49dd9bf505bbe6a61 DB=myopic_vicar_develomment MONGO_URI=mongodb://127.0.0.1:27017"
  task :scan_id do
    id_str   = ENV['ID'] || '691b73b49dd9bf505bbe6a61'
    db_name  = ENV['DB'] || 'myopic_vicar_development'
    uri      = ENV['MONGO_URI'] || "mongodb://mongo:27017"
    # uri      = ENV['MONGO_URI'] || "mongodb://127.0.0.1:27017"

    begin
      id = BSON::ObjectId.from_string(id_str)
    rescue => e
      puts "Invalid ID: #{id_str} (#{e.message})"
      exit 1
    end

    client = nil
    begin
      client = Mongo::Client.new(uri, database: db_name)
      # Get collection names in a way that works across driver versions
      collections = if client.database.respond_to?(:collection_names)
                      client.database.collection_names
                    else
                      client.database.collections.map(&:name)
                    end

      puts "---Scanning #{collections.size} collections in database '#{db_name}' for _id=#{id_str}..."

      found_any = false
      collections.each do |coll_name|
        coll = client[coll_name]
        doc = coll.find(_id: id).first
        if doc
          found_any = true
          puts "-" * 80
          puts "+++ Found in collection: #{coll_name}"
          puts doc.inspect
          # awesome print found record
          ap doc
        end
      end

      puts "-" * 80
      puts found_any ? "---Scan complete. Document(s) found." : "Scan complete. No document found with _id=#{id_str}."
    rescue => e
      puts "Error connecting or scanning: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    ensure
      client&.close
    end
  end
end
