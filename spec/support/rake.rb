require "rake"

Rails.application.load_tasks unless Rake::Task.task_defined?("gallery_photos:backfill")
