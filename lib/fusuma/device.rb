# frozen_string_literal: true

module Fusuma
  # detect input device
  class Device
    attr_reader :available
    attr_reader :name
    attr_reader :id

    def initialize(id: nil, name: nil, available: nil)
      @id = id
      @name = name
      @available = available
    end

    # @param attributes [Hash]
    def assign_attributes(attributes)
      attributes.each do |k, v|
        case k
        when :id
          @id = v
        when :name
          @name = v
        when :available
          @available = v
        end
      end
    end

    class << self
      attr_reader :given_devices

      # @return [Array]
      def all
        @all ||= fetch_devices
      end

      # @raise [SystemExit]
      # @return [Array]
      def available
        @available ||= all.select(&:available).tap do |d|
          MultiLogger.debug(available_devices: d)
          raise 'Touchpad is not found' if d.empty?
        end
      rescue RuntimeError => e
        # FIXME: should not exit without Runner class
        MultiLogger.error(e.message)
        exit 1
      end

      def reset
        @all = nil
        @available = nil
      end

      # Narrow down available device list
      # @param names [String, Array]
      def given_devices=(names)
        # NOTE: convert to Array
        device_names = Array(names)
        return if device_names.empty?

        @given_devices = narrow_available_devices(device_names: device_names)
        return unless @given_devices.empty?

        exit 1
      end

      private

      # @return [Array]
      def fetch_devices
        line_parser = LineParser.new
        Plugin::Inputs::LibinputCommandInput.new.list_devices do |line|
          line_parser.push(line)
        end
        line_parser.generate_devices
      end

      def narrow_available_devices(device_names:)
        device_names.select do |name|
          if available.map(&:name).include? name
            MultiLogger.info("Touchpad is found: #{name}")
            true
          else
            MultiLogger.warn("Touchpad is not found: #{name}")
          end
        end
      end

      # parse line and generate devices
      class LineParser
        attr_reader :lines

        def initialize
          @lines = []
        end

        # @param line [String]
        def push(line)
          lines.push(line)
        end

        # @return [Array]
        def generate_devices
          device = Device.new
          lines.each_with_object([]) do |line, devices|
            attributes = extract_attribute(line: line)

            # detect new line including device name
            if attributes[:name] && (device&.name != attributes[:name])
              devices << device
              device = Device.new
            end

            devices.last.assign_attributes(attributes)
          end
        end

        # @param line [String]
        # @return [Hash]
        def extract_attribute(line:)
          if (id = id_from(line))
            { id: id }
          elsif (name = name_from(line))
            { name: name }
          elsif (available = available_from(line))
            { available: available }
          else
            {}
          end
        end

        def id_from(line)
          line.match('^Kernel:[[:space:]]*') do |m|
            m.post_match.match(/event[0-9]+/).to_s
          end
        end

        def name_from(line)
          line.match('^Device:[[:space:]]*') do |m|
            m.post_match.strip
          end
        end

        def available_from(line)
          # NOTE: is natural scroll available?
          if line =~ /^Nat.scrolling: /
            return false if line =~ %r{n/a}

            return true # disabled / enabled
          end
          nil
        end
      end
    end
  end
end
