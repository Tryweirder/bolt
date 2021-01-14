# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/yaml_plan/loader'
require 'bolt/util'

module Bolt
  class PAL
    class YamlPlan
      class Transpiler
        class ConvertError < Bolt::Error
          def initialize(msg, plan_path)
            super(msg, 'bolt/convert-error', { "plan_path" => plan_path })
          end
        end

        def transpile(relative_path)
          @plan_path = File.expand_path(relative_path)
          @modulename = Bolt::Util.module_name(@plan_path)
          @filename = @plan_path.split(File::SEPARATOR)[-1]
          validate_path

          plan_object = parse_plan
          param_descriptions = plan_object.parameters.map do |param|
            str = String.new("# @param #{param.name}")
            str << " #{param.description}" if param.description
            str
          end.join("\n")

          plan_string = String.new('')
          plan_string << "# #{plan_object.description}\n" if plan_object.description
          plan_string << "# WARNING: This is an autogenerated plan. It may not behave as expected.\n"
          plan_string << "# @private #{plan_object.private}\n" unless plan_object.private.nil?
          plan_string << "#{param_descriptions}\n" unless param_descriptions.empty?

          plan_string << "plan #{plan_object.name}("
          # Parameters are Bolt::PAL::YamlPlan::Parameter
          plan_object.parameters&.each_with_index do |param, i|
            plan_string << param.transpile

            # If it's the last parameter add a newline and no comma
            last = i + 1 == plan_object.parameters.length ? "\n" : ","
            # This encodes strangely if we << directly to plan_string
            plan_string << last
          end
          plan_string << ") {\n"

          plan_object.steps&.each do |step|
            plan_string << step.transpile
          end

          plan_string << "\n  return #{Bolt::Util.to_code(plan_object.return)}\n" if plan_object.return
          plan_string << "}"
          # We always print the plan, even if there's an error
          puts plan_string
          validate_plan(plan_string)
          plan_string
        end

        def parse_plan
          begin
            file_contents = File.read(@plan_path)
          rescue Errno::ENOENT
            msg = "Could not read yaml plan file: #{@plan_path}"
            raise Bolt::FileError.new(msg, @plan_path)
          end

          begin
            Bolt::PAL::YamlPlan::Loader.from_string(@modulename, file_contents, @plan_path)
          rescue Puppet::PreformattedError, StandardError => e
            raise PALError.from_preformatted_error(e)
          end
        end

        def validate_path
          unless File.extname(@filename) == ".yaml"
            raise ConvertError.new("You can only convert plans written in yaml", @plan_path)
          end
        end

        def validate_plan(plan)
          Puppet::Pops::Parser::EvaluatingParser.new.parse_string(plan)
        rescue Puppet::Error => e
          $stderr.puts "The converted puppet plan contains invalid puppet code: #{e.message}"
          exit 1
        end
      end
    end
  end
end
