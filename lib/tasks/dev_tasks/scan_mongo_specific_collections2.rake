# lib/tasks/dev_tasks/scan_mongo_collections2.rake
require 'mongo'
require 'bson'

namespace :mongo do
  desc "Scan specific collections and embedded relations for a given _id."
  task :scan_id2 do
    id_str   = ENV['ID'] || '691b73b49dd9bf505bbe6a61'
    db_name  = ENV['DB'] || 'myopic_vicar_development'
    uri      = ENV['MONGO_URI'] || "mongodb://mongo:27017"

    begin
      target_id = BSON::ObjectId.from_string(id_str)
    rescue => e
      puts "Invalid ID: #{id_str} (#{e.message})"
      exit 1
    end

    # -------------------------------------------------------------------
    # CONFIGURATION: Only scan these collections and embedded relations
    # -------------------------------------------------------------------
    TARGET_COLLECTIONS = {
      "search_records" => ["search_names"]  # embedded relations to scan
    }.freeze

    client = Mongo::Client.new(uri, database: db_name)

    puts "---Scanning targeted collections in '#{db_name}' for _id=#{id_str}..."
    puts

    found_any = false

    TARGET_COLLECTIONS.each do |collection_name, embedded_relations|
      coll = client[collection_name]

      puts "---Scanning collection: #{collection_name}"

      # 1. Scan top-level documents
      top_doc = coll.find(_id: target_id).first
      if top_doc
        found_any = true
        puts "-" * 80
        puts "+++ Found TOP-LEVEL document in #{collection_name}"
        ap top_doc
      end

      # 2. Scan embedded relations
      coll.find.each do |parent_doc|
        embedded_relations.each do |relation|
          next unless parent_doc[relation].is_a?(Array)

          parent_doc[relation].each_with_index do |embedded_doc, idx|
            if embedded_doc["_id"] == target_id
              found_any = true
              puts "-" * 80
              puts "+++ Found EMBEDDED document"
              puts "Collection: #{collection_name}"
              puts "Parent document _id: #{parent_doc['_id']}"
              puts "Embedded relation: #{relation}"
              puts "Index: #{idx}"
              ap embedded_doc
            end
          end
        end
      end

      puts
    end

    puts "-" * 80
    puts found_any ? "+++ --- Scan complete. Document(s) found." :
                     "Scan complete. No document found with _id=#{id_str}."

  rescue => e
    puts "Error: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  ensure
    client&.close
  end
end