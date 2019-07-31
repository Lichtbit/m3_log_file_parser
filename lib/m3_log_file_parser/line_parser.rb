M3LogFileParser::LineParser = Struct.new(:worker, :line) do
  delegate :requests, to: :worker

  def perform
    return if line.strip == ''

    # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN

    match = line.match(/\ASent\smail\sto/)
    if match
      worker.mail_sent
      return
    end

    match = line.match(/\A(?<severity_id>[DIWEFU]),\s\[(?<datetime>[^\]]+)\s#(?<pid>\d+)\]\s+(?<severity_label>[A-Z]+)\s+--\s+[^:]*:\s+\[(?<id>[a-f0-9\-]{36})\]\s\[(?<domain>[^\]]+)\]\s*\z/)
    return if match

    match = line.match(/\A(?<severity_id>[DIWEFU]),\s\[(?<datetime>[^\]]+)\s#(?<pid>\d+)\]\s+(?<severity_label>[A-Z]+)\s+--\s+[^:]*:\s+\[(?<id>[a-f0-9\-]{36})\]\s\[(?<domain>[^\]]+)\]\s(?<message>.*)\z/)
    if match
      requests[match[:id]] ||= M3LogFileParser::Request.new(match[:datetime], match[:pid], match[:domain])
      requests[match[:id]].severity(match[:severity_id])
      requests[match[:id]].push(match[:message].strip)
      worker.line_mode = match[:id]
      return
    end

    match = line.match(/\A(?<severity_id>[DIWEFU]),\s\[(?<datetime>[^\]]+)\s#(?<pid>\d+)\]\s+(?<severity_label>[A-Z]+)\s+--\s+[^:]*:\s+\[(?<id>[a-f0-9\-]{36})\]\s(?<message>.*)\z/)
    if match
      requests[match[:id]] ||= M3LogFileParser::Request.new(match[:datetime], match[:pid], nil)
      requests[match[:id]].severity(match[:severity_id])
      requests[match[:id]].push(match[:message].strip)
      worker.line_mode = match[:id]
      return
    end

    match = line.match(/\A(?<severity_id>[DIWEFU]),\s\[(?<datetime>[^\]]+)\s#(?<pid>\d+)\]\s+(?<severity_label>[A-Z]+)\s+--\s+[^:]*:\s+\[ActiveJob\](\s\[[^\]]+\])?(\s\[[^\]]+\])?\s(?<message>.*)\z/)
    if match
      worker.line_mode = :active_job
      return
    end

    match = line.match(/\A(?<severity_id>[DIWEFU]),\s\[(?<datetime>[^\]]+)\s#(?<pid>\d+)\]\s+(?<severity_label>[A-Z]+)\s+--\s+[^:]*:\s(?<message>.*)\z/)
    if match
      worker.line_mode = :delayed_job
      return
    end

    if worker.line_mode.present? && requests[worker.line_mode].present?
      requests[worker.line_mode].stacktrace.push(line.strip)
      return
    end

    worker.line_mode = nil

    line
  end
end
