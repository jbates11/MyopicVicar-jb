namespace :admin do
  # desc 'Interactively delete all files in /tmp'

  # Multiline rake description
  desc <<~LID
    Interactively delete all files in /tmp
    Do nothing, even when arguments are provided.
    Usage:
      rake 'admin:clean_tmp["something", "anotherthing"]'
      rake 'admin:clean_tmp[, "anotherthing"]' # something is ignored anyway
      rake admin:clean_tmp # do nothing new 
  LID
  task clean_tmp: :environment do
    Dir[Rails.root.join('tmp/*').to_s].each do |f|
      # p Rails.root.join('tmp/*').to_s
      next unless File.file?(f)

      print "Delete #{f}? "
      answer = $stdin.gets
      case answer
      when /^y/
        File.unlink(f)
      when /^q/
        break
      end
    end
  end
end
