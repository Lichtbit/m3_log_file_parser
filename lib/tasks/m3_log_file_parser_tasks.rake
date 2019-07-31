namespace :m3 do
  desc 'parse a given logfile and generate summary'
  task :log_file_parser, [:log_path] => :environment do |_task, args|
    log_path = args[:log_path]
    config = nil
    if Rails.configuration.respond_to?(:log_file_parser)
      config = Rails.configuration.log_file_parser

      log_path ||= Dir.entries(config.file_path).select do |file|
        File.file?(File.join(config.file_path, file)) && config.file_pattern.match(file)
      end.sort.map { |file| File.join(config.file_path, file) }.last
    elsif log_path && File.file?(log_path)
      config = OpenStruct.new(output_level: :warn)
    else
      puts 'Not configured'
      next
    end

    next puts 'No log file found' if log_path.empty?

    M3LogFileParser::Worker.new(log_path).perform(config.output_level || :fatal)
  end
end
