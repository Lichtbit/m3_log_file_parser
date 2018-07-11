namespace :m3 do
  desc 'parse a given logfile and generate summary'
  task :log_file_parser, [:log_path] => :environment do |task, args|
    config = Rails.configuration.log_file_parser
    return unless config

    log_path ||= Dir.entries(config.file_path).select do |file|
      File.file?(File.join(config.file_path, file)) && config.file_pattern.match(file)
    end.sort.map { |file| File.join(config.file_path, file) }.last

    return puts 'No log file found' if log_path.empty?
    M3LogFileParser::Worker.new(log_path).perform(config.output_level || :fatal)
  end
end
