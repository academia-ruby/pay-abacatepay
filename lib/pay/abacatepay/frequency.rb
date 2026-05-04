module Pay
  module Abacatepay
    module Frequency
      INTERVALS = {
        "WEEKLY" => 1.week,
        "MONTHLY" => 1.month,
        "SEMIANNUALLY" => 6.months,
        "ANNUALLY" => 1.year
      }.freeze

      def self.to_interval(freq)
        INTERVALS[freq]
      end

      def self.valid?(freq)
        INTERVALS.key?(freq)
      end
    end
  end
end
