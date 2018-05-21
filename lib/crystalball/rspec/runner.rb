# frozen_string_literal: true

require 'rspec/core'
require 'crystalball/rspec/prediction_builder'

module Crystalball
  module RSpec
    # Our custom RSpec runner to run predictions
    class Runner < ::RSpec::Core::Runner
      class << self
        def run(args, err = $stderr, out = $stdout)
          return config['runner_class'].run(args, err, out) unless config['runner_class'] == self

          out.puts "Crystalball starts to glow..."
          prediction = build_prediction(out)

          check_limit(out) { prediction.size } # Actual examples size is not less than prediction size.

          super(args + prediction, err, out)
        end

        def reset!
          self.prediction_builder = nil
          self.config = nil
        end

        def prepare
          config['runner_class'].load_map
        end

        def prediction_builder
          @prediction_builder ||= PredictionBuilder.new(config)
        end

        def config
          @config ||= begin
            config_src = if config_file
                           require 'yaml'
                           YAML.safe_load(config_file.read)
                         else
                           {}
                         end

            Configuration.new(config_src)
          end
        end

        def check_limit(out)
          limit = config['examples_limit'].to_i
          return if ENV['CRYSTALBALL_SKIP_EXAMPLES_LIMIT'] || !limit.positive?

          examples_count = yield
          return if examples_count <= limit

          out.puts "Example group size (#{examples_count}) is over the limit (#{limit})"
          out.puts "Aborting spec run"
          exit
        end

        protected

        def load_map
          check_map($stdout) unless ENV['CRYSTALBALL_SKIP_MAP_CHECK']
          prediction_builder.map
        end

        private

        attr_writer :config, :prediction_builder

        def config_file
          file = Pathname.new(ENV.fetch('CRYSTALBALL_CONFIG', 'crystalball.yml'))
          file = Pathname.new('config/crystalball.yml') unless file.exist?
          file.exist? ? file : nil
        end

        def build_prediction(out)
          check_map(out) unless ENV['CRYSTALBALL_SKIP_MAP_CHECK']
          prediction = prediction_builder.prediction.sort_by(&:length)
          out.puts "Prediction: #{prediction.first(5).join(' ')}#{'...' if prediction.size > 5}"
          out.puts "Starting RSpec."
          prediction
        end

        def check_map(out)
          out.puts 'Maps are outdated!' if prediction_builder.expired_map?
        end
      end

      def run_specs(example_groups)
        check_examples_limit(example_groups)
        super
      end

      def check_examples_limit(example_groups)
        self.class.check_limit(@configuration.output_stream) { @world.example_count(example_groups) }
      end
    end
  end
end

require 'crystalball/rspec/runner/configuration'