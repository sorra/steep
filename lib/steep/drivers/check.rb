module Steep
  module Drivers
    class Check
      attr_reader :source_paths
      attr_reader :signature_dirs
      attr_reader :stdout
      attr_reader :stderr

      attr_accessor :verbose
      attr_accessor :accept_implicit_any

      def initialize(source_paths:, signature_dirs:, stdout:, stderr:)
        @source_paths = source_paths
        @signature_dirs = signature_dirs
        @stdout = stdout
        @stderr = stderr

        self.verbose = false
        self.accept_implicit_any = false
      end

      def run
        assignability = TypeAssignability.new

        each_interface do |interface|
          assignability.add_interface(interface)
        end

        sources = []
        each_ruby_source do |source|
          sources << source
        end

        typing = Typing.new

        sources.each do |source|
          stdout.puts "Typechecking #{source.path}..." if verbose
          env = TypeEnv.from_annotations(source.annotations(block: source.node) || [], env: {})
          construction = TypeConstruction.new(assignability: assignability, env: env, source: source, typing: typing)
          construction.run(source.node)
        end

        p typing if verbose

        typing.errors.each do |error|
          stdout.puts error.inspect
        end
      end

      def each_interface
        signature_dirs.each do |path|
          if path.file?
            stdout.puts "Loading signature #{path}..." if verbose
            Parser.parse_interfaces(path.read).each do |interface|
              yield interface
            end
          end

          if path.directory?
            each_file_in_dir(".rbi", path) do |file|
              stdout.puts "Loading signature #{file}..." if verbose
              Parser.parse_interfaces(file.read).each do |interface|
                yield interface
              end
            end
          end
        end
      end

      def each_ruby_source
        source_paths.each do |path|
          if path.file?
            stdout.puts "Loading Ruby program #{path}..." if verbose
            yield Source.parse(path.read, path: path.to_s)
          end

          if path.directory?
            each_file_in_dir(".rb", path) do |file|
              stdout.puts "Loading Ruby program #{file}..." if verbose
              yield Source.parse(file.read, path: file.to_s)
            end
          end
        end
      end

      def each_file_in_dir(suffix, path, &block)
        path.children.each do |child|
          if child.directory?
            each_file_in_dir(suffix, child, &block)
          end

          if child.file? && suffix == child.extname
            yield child
          end
        end
      end
    end
  end
end