require "test_helper"

module Pay
  module Abacatepay
    class FrequencyTest < ActiveSupport::TestCase
      test "to_interval returns matching ActiveSupport::Duration for known cycles" do
        assert_equal 1.week, Frequency.to_interval("WEEKLY")
        assert_equal 1.month, Frequency.to_interval("MONTHLY")
        assert_equal 6.months, Frequency.to_interval("SEMIANNUALLY")
        assert_equal 1.year, Frequency.to_interval("ANNUALLY")
      end

      test "to_interval returns nil for unknown cycle" do
        assert_nil Frequency.to_interval("DAILY")
        assert_nil Frequency.to_interval(nil)
      end

      test "valid? is true for known cycles and false otherwise" do
        assert Frequency.valid?("MONTHLY")
        refute Frequency.valid?("DAILY")
        refute Frequency.valid?(nil)
        refute Frequency.valid?("")
      end

      test "INTERVALS is frozen" do
        assert Frequency::INTERVALS.frozen?
      end
    end
  end
end
