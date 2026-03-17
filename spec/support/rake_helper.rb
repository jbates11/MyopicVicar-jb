require "rake"

module RakeHelper
  def run_rake(task_name, *args)
    # Fresh Rake application for full isolation
    Rake.application = Rake::Application.new

    # Stub the environment task so prerequisites resolve
    Rake.application.define_task(Rake::Task, :environment)

    #  JC for my files only
    load Rails.root.join("lib/tasks/dev_tasks/ucf.rake")

    # Load all rake tasks from lib/tasks and lib/tasks/dev_tasks
    # Dir[Rails.root.join("lib/tasks/**/*.rake")].each do |task_file|
    #   load task_file
    # end

    # Re-enable and invoke the task
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke(*args)
  end
end
