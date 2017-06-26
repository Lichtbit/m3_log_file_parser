namespace :m3 do
  desc 'parse a given logfile and generate summary'
  task :log_file_parser, [:log_path] => :environment do |task, args|
    configuration = Rails.configuration.log_file_parser
    only_env = configuration.only_env
    only_env = [only_env] if only_env.present? && !only_env.is_a?(Array)
    next if only_env.present? && !Rails.env.to_sym.in?(only_env.map(&:to_sym))

    log_path = args[:log_path] || configuration.log_path
    configuration.run_before.call if configuration.run_before.respond_to?(:call)

    worker = M3LogFileParser::Worker.new(log_path)
    worker.perform
    if configuration.output_if.respond_to?(:call)
      puts worker.generate_message if configuration.output_if.call(worker)
    else
      puts worker.generate_message
    end

    configuration.run_after.call if configuration.run_after.respond_to?(:call)
  end
end
