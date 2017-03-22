module Xronor
  class DSL
    class ScheduleConverter
      WEEKDAYS = %i(sunday monday tuesday wednesday thursday friday saturday)

      class << self
        def convert(frequency, options)
          self.new(frequency, options).convert
        end
      end

      def initialize(frequency, options)
        @frequency = frequency
        @options = options
      end

      def convert
        cron_at, dow_diff = case @options[:at]
                            when String
                              parse_and_convert_time
                            when Numeric
                              [@options[:at], 0]
                            else
                              [0, 0]
                            end

        if WEEKDAYS.include?(@frequency) # :sunday, :monday, ..., :saturday
          return cron_weekly(cron_at, dow_diff)
        end

        shortcut = case @frequency
                   when Numeric
                     @frequency
                   when :minute
                     Xronor::DSL.seconds(1, :minute)
                   when :hour
                     Xronor::DSL.seconds(1, :hour)
                   when :day
                     Xronor::DSL.seconds(1, :day)
                   end

        raise ArgumentError, "Invalid frequency #{@frequency}" if !shortcut.is_a?(Numeric)

        cron(shortcut, cron_at)
      end

      private

      def comma_separated_timing(frequency, max, start = 0)
        return start     if frequency.nil? || frequency == "" || frequency == 0
        return "*"       if frequency == 1
        return frequency if frequency > (max * 0.5) .ceil

        original_start = start

        start += frequency unless (max + 1).modulo(frequency).zero? || start > 0
        output = (start..max).step(frequency).to_a

        max_occurances = (max.to_f  / (frequency.to_f)).round
        max_occurances += 1 if original_start.zero?

        output[0, max_occurances].join(',')
      end

      def cron(shortcut, cron_at)
        digits = ["*", "*", "*", "*", "*"]

        case shortcut
        when Xronor::DSL.seconds(0, :second)...Xronor::DSL.seconds(1, :minute)
          raise ArgumentError, "Time must be in minutes or higher"
        when Xronor::DSL.seconds(1, :minute)...Xronor::DSL.seconds(1, :hour)
          min_frequency = shortcut / 60
          digits[0] = comma_separated_timing(min_frequency, 59, cron_at.is_a?(Time) ? cron_at.min : 0)
        when Xronor::DSL.seconds(1, :hour)...Xronor::DSL.seconds(1, :day)
          hour_frequency = (shortcut / 60 / 60).round
          digits[0] = cron_at.is_a?(Time) ? cron_at.min : cron_at
          digits[1] = comma_separated_timing(hour_frequency, 23, cron_at.is_a?(Time) ? cron_at.hour : 0)
        when Xronor::DSL.seconds(1, :day)...Xronor::DSL.seconds(1, :month)
          day_frequency = (shortcut / 24 / 60 / 60).round
          digits[0] = cron_at.is_a?(Time) ? cron_at.min : 0
          digits[1] = cron_at.is_a?(Time) ? cron_at.hour : cron_at
          digits[2] = comma_separated_timing(day_frequency, 31, 1)
        end

        digits.join(" ")
      end

      def cron_weekly(cron_at, dow_diff)
        dow = WEEKDAYS.index(@frequency)
        dow += dow_diff

        case dow
        when -1 # Sunday -> Saturday
          dow = 6
        when 7  # Saturday -> Sunday
          dow = 0
        end

        [
          cron_at.is_a?(Time) ? cron_at.min : "0",
          cron_at.is_a?(Time) ? cron_at.hour : "0",
          "*",
          "*",
          dow,
        ].join(" ")
      end

      def parse_and_convert_time
        original_time_class = Chronic.time_class
        Time.zone = @options[:timezone]
        Chronic.time_class = Time.zone
        local_at = Chronic.parse(@options[:at])
        cron_at = local_at.in_time_zone(@options[:cron_timezone])
        Chronic.time_class = original_time_class

        return cron_at, (cron_at.wday - local_at.wday)
      end
    end
  end
end