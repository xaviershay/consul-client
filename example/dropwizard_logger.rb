# This is completely unrelated to consul, but makes examples much easier to
# read than default webrick logging.
class DropwizardLogger < Logger
  def initialize(label, *args)
    super(*args)
    @label = label
  end

  def format_message(severity, timestamp, progname, msg)
    "%-5s [%s] %s: %s\n" % [
      severity,
      timestamp.utc.strftime("%Y-%m-%d %H:%M:%S,%3N"),
      @label,
      msg2str(msg),
    ]
  end

  def msg2str(msg)
    case msg
    when String
      msg
    when Exception
      ("%s: %s" % [msg.class, msg.message]) +
        (msg.backtrace ? msg.backtrace.map {|x| "\n! #{x}" }.join : "")
    else
      msg.inspect
    end
  end

  def self.webrick_format(label)
    "INFO  [%{%Y-%m-%d %H:%M:%S,%3N}t] #{label}: %m %U %s"
  end
end
