# frozen_string_literal: true

require 'spec_helper'

require './lib/fusuma/plugin/detectors/pinch_detector.rb'
require './lib/fusuma/plugin/buffers/gesture_buffer.rb'
require './lib/fusuma/plugin/events/event.rb'
require './lib/fusuma/config.rb'

module Fusuma
  module Plugin
    module Detectors
      RSpec.describe PinchDetector do
        before do
          @detector = PinchDetector.new
          @buffer = Buffers::GestureBuffer.new
        end

        around do |example|
          ConfigHelper.load_config_yml = <<~CONFIG
            threshold:
              rotate: 1
          CONFIG

          example.run

          Config.custom_path = nil
        end

        describe '#detect' do
          context 'with no pinch event in buffer' do
            before do
              @buffer.clear
            end
            it { expect(@detector.detect([@buffer])).to eq nil }
          end

          context 'with not enough pinch events in buffer' do
            before do
              directions = [
                Events::Records::GestureRecord::Delta.new(0, 0, 1, 0),
                Events::Records::GestureRecord::Delta.new(0, 0, 1.1, 0)
              ]
              events = create_events(directions: directions)

              events.each { |event| @buffer.buffer(event) }
            end
            it { expect(@detector.detect([@buffer])).to eq nil }
          end

          context 'with enough pinch IN event' do
            before do
              directions = [
                Events::Records::GestureRecord::Delta.new(0, 0, 1.0, 0),
                Events::Records::GestureRecord::Delta.new(0, 0, 1.2, 0)
              ]
              events = create_events(directions: directions)

              events.each { |event| @buffer.buffer(event) }
            end
            it { expect(@detector.detect([@buffer])).to be_a Events::Event }
            it { expect(@detector.detect([@buffer]).record).to be_a Events::Records::IndexRecord }
            it { expect(@detector.detect([@buffer]).record.index).to be_a Config::Index }

            it 'should detect 3 fingers pinch-in' do
              expect(@detector.detect([@buffer]).record.index.keys.map(&:symbol))
                .to eq([:pinch, 3, :in])
            end
          end

          context 'with enough pinch OUT event' do
            before do
              directions = [
                Events::Records::GestureRecord::Delta.new(0, 0, 1.0, 0),
                Events::Records::GestureRecord::Delta.new(0, 0, 0.7, 0)
              ]
              events = create_events(directions: directions)

              events.each { |event| @buffer.buffer(event) }
            end
            it 'should detect 3 fingers pinch-out' do
              expect(@detector.detect([@buffer]).record.index.keys.map(&:symbol))
                .to eq([:pinch, 3, :out])
            end
          end
        end

        private

        def create_events(directions: [])
          record_type = PinchDetector::GESTURE_RECORD_TYPE
          directions.map do |direction|
            gesture_record = Events::Records::GestureRecord.new(status: 'update',
                                                                gesture: record_type,
                                                                finger: 3,
                                                                direction: direction)
            Events::Event.new(tag: 'libinput_gesture_parser', record: gesture_record)
          end
        end
      end
    end
  end
end
