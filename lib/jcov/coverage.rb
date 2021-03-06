module JCov
  module Coverage

    # Make our own RKelly's Visitor
    class CoverageVisitor < RKelly::Visitors::Visitor
      def initialize(coverage)
        @coverage = coverage
        @indent = 0
      end

      # whenever we hit a line, add the instrumentation
      def visit_SourceElementsNode(o)
        o.value.each do |x|
          # function statements are given the wrong line numbers
          # line = if x.is_a?(RKelly::Nodes::ExpressionStatementNode) &&
          #           x.value.is_a?(RKelly::Nodes::OpEqualNode) &&
          #           x.value.value.respond_to?(:line)
          #          x.value.value.line
          #        else
          #          x.line
          #        end
          # puts x.inspect if x.line == 21
          line = x.line
          @coverage[x.filename][line] = 0 if x.filename && line
          x.accept(self)
        end
      end
    end


    class CoverageRunner
      attr_reader :config
      attr_reader :options
      attr_reader :runner
      attr_reader :instrumented_files

      def initialize config, options
        @config  = config
        @options = options

        @runner = JCov::Runner.new(config, options)

        override_runners_load_method
        add_coverage_method_to_context

        @visitor = CoverageVisitor.new(coverage_data)
        @parser  = RKelly::Parser.new

        @instrumented_files = {}
      end

      def coverable_files
        if @coverable_files.nil?
          # all the files we're testing on
          @coverable_files = Dir.glob(File.join(config.source_directory, "**", "*.js"))
          # only run coverage on files that we haven't specifically ignored
          ignore = config.ignore || []
          @coverable_files.delete_if {|file| ignore.any? {|i| file.match(i) }}
          # remove the runner if it's in there
          @coverable_files.delete(config.test_runner)
        end
        @coverable_files
      end

      def coverage_data
        if @coverage_data.nil?
          # set up coverage data structure
          @coverage_data = {}
          coverable_files.each {|file| @coverage_data[file] = {} }
        end
        @coverage_data
      end

      # our new load method
      def load file
        if instrumented_files[file]
          # reuse previously loaded file
          content = instrumented_files[file]
        else
          content = File.read(file)

          # is this a file we need to instrument?
          if coverable_files.include? file
            # run it through the js parser to get coverage data
            tree = @parser.parse(content, file)
            @visitor.accept(tree)

            # update the content with the coverage instrumentations
            content = instrument_script(content, file)

            # cache the file if it's reloaded
            instrumented_files[file] = content
          end
        end

        runner.context.eval(content, file)
      end

      def _coverage_tick file, line
        coverage_data[file][line] += 1
      end

      def run
        runner.run
      end

      # proxy to runner
      def failure_count
        runner.failure_count
      end

      # reduce the coverage data to file, total line count, and covered line count
      def reduced_coverage_data
        if @reduced_coverage_data.nil?
          @reduced_coverage_data = coverage_data.map do |file, lines|
            # if we don't have any data for this file it was never loaded
            if lines.empty?
              # load it now
              content = File.read(file)

              # run it through the js parser and custom renderer
              # the visitor will fill out the coverage data for this line
              tree = @parser.parse(content, file)
              @visitor.accept(tree)

              # re-get the lines
              lines = coverage_data[file]

              # this file was never run
              cover = 0
            else
              # munge the count data together to get coverage
              cover = lines.values.inject(0) { |memo, count| memo + ((count > 0) ? 1 : 0) }
            end

            total = lines.count

            [file, total, cover]
          end
        end
        @reduced_coverage_data
      end

      def get_binding
        binding
      end

    private

      def add_coverage_method_to_context
        runner.context['_coverage_tick'] = self.method('_coverage_tick')
      end

      def override_runners_load_method
        runner.context['load'] = self.method('load')
      end

      def instrument_script content, filename
        lines = coverage_data[filename] || {}
        line_number = 0
        output = ""

        StringIO.new(content).each_line do |line|
          line_number += 1
          if lines.has_key? line_number
            output << "_coverage_tick('#{filename}', #{line_number});"
          end
          output << line
        end

        puts output

        output
      end

    end

  end
end
