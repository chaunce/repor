require 'repor/inflector'
require 'repor/dimension/bin'

module Repor
  module Dimension
    class Time < Bin
      STEPS = %i(seconds minutes hours days weeks months years)
      BIN_STEPS = (STEPS - [:seconds]).map { |step| step.to_s.singularize(:_gem_repor) }
      DURATION_PATTERN = /\A\d+ (?:#{STEPS.map{ |step| "#{step}?" }.join('|')})\z/

      def validate_params!
        super

        invalid_param!(:bin_width, "must be a hash of one of #{STEPS} to an integer") if params.key?(:bin_width) && !valid_duration?(params[:bin_width])
      end

      def bin_width
        @bin_width ||= case
        when params.key?(:bin_width)
          custom_bin_width
        when params.key?(:bin_count) && domain > 0
          (domain / params[:bin_count].to_f).seconds
        else
          default_bin_width
        end
      end

      def bin_start
        # ensure that each autogenerated bin represents a correctly aligned
        # day/week/month/year
        bin_start = super
        
        return if bin_start.nil?

        step = BIN_STEPS.detect { |step| bin_width == 1.send(step) }
        step.present? ? bin_start.send(:"beginning_of_#{step}") : bin_start
      end

      private

      def custom_bin_width
        case params[:bin_width]
        when Hash
          params[:bin_width].map { |step, n| n.send(step) }.sum
        when String
          n, step = params[:bin_width].split.map(&:strip)
          n.to_i.send(step)
        end
      end

      def valid_duration?(d)
        case d
        when Hash
          d.all? { |step, n| step.to_sym.in?(STEPS) && n.is_a?(Numeric) }
        when String
          d =~ DURATION_PATTERN
        else
          false
        end
      end

      def default_bin_width
        case domain
        when 0 then 1.day
        when 0..1.minute then 1.second
        when 0..2.hours then 1.minute
        when 0..2.days then 1.hour
        when 0..2.weeks then 1.day
        when 0..2.months then 1.week
        when 0..2.years then 1.month
        else 1.year
        end
      end

      class Set < Bin::Set
        def parse(value)
          ::Time.zone.parse(value.to_s.gsub('"', ''))
        end

        def cast(value)
          case Repor.database_type
          when :postgres
            "CAST(#{super} AS timestamp with time zone)"
          when :sqlite
            "DATETIME(#{super})"
          else
            "CAST(#{super} AS DATETIME)"
          end
        end
      end
    end
  end
end
