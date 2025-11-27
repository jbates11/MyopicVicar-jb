Rails.application.config.after_initialize do
  if Rails.env.development?
    Rails.logger.info "Ensuring MongoDB indexes (development only)..."
    # SearchRecord.ensure_all_indexes!
  end
end
