module Jekyll
  class IncludeIfExistsError < StandardError
      attr_accessor :path

      def initialize(msg, path)
        super(msg)
        @path = path
      end
    end

  class IncludeIfExists < Liquid::Tag

      SYNTAX_EXAMPLE = "{% include_if_exists file.ext param='value' param2='value' %}"

      VALID_SYNTAX = /([\w-]+)\s*=\s*(?:"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|([\w\.-]+))/
      VARIABLE_SYNTAX = /(?<variable>\{\{\s*(?<name>[\w\-\.]+)\s*(\|.*)?\}\})(?<params>.*)/

      INCLUDES_DIR = '_includes'

      def initialize(tag_name, markup, tokens)
        super
        matched = markup.strip.match(VARIABLE_SYNTAX)
        if matched
          @file = matched['variable'].strip
          @params = matched['params'].strip
        else
          @file, @params = markup.strip.split(' ', 2);
        end
        validate_params if @params
      end

      def parse_params(context)
        params = {}
        markup = @params

        while match = VALID_SYNTAX.match(markup) do
          markup = markup[match.end(0)..-1]

          value = if match[2]
            match[2].gsub(/\\"/, '"')
          elsif match[3]
            match[3].gsub(/\\'/, "'")
          elsif match[4]
            context[match[4]]
          end

          params[match[1]] = value
        end
        params
      end

      def validate_file_name(file)
        if file !~ /^[a-zA-Z0-9_\/\.-]+$/ || file =~ /\.\// || file =~ /\/\./
            raise ArgumentError.new <<-eos
Invalid syntax for include tag. File contains invalid characters or sequences:

#{file}

Valid syntax:

#{SYNTAX_EXAMPLE}

eos
        end
      end

      def validate_params
        full_valid_syntax = Regexp.compile('\A\s*(?:' + VALID_SYNTAX.to_s + '(?=\s|\z)\s*)*\z')
        unless @params =~ full_valid_syntax
          raise ArgumentError.new <<-eos
Invalid syntax for include tag:

#{@params}

Valid syntax:

#{SYNTAX_EXAMPLE}

eos
        end
      end

      # Grab file read opts in the context
      def file_read_opts(context)
        context.registers[:site].file_read_opts
      end

      # Render the variable if required
      def render_variable(context)
        if @file.match(VARIABLE_SYNTAX)
          partial = Liquid::Template.parse(@file)
          partial.render!(context)
        end
      end

      def render(context)
        dir = File.join(File.realpath(context.registers[:site].source), INCLUDES_DIR)

        file = render_variable(context) || @file
        validate_file_name(file)

        path = File.join(dir, file)

        if(!validate_path(path, dir, context.registers[:site].safe))
          return ""
        end

        begin
          partial = Liquid::Template.parse(source(path, context))

          context.stack do
            context['include'] = parse_params(context) if @params
            partial.render!(context)
          end
        rescue => e
          raise IncludeIfExistsError.new e.message, File.join(INCLUDES_DIR, @file)
        end
      end

      def validate_path(path, dir, safe)
        if safe && !realpath_prefixed_with?(path, dir)
          return false
        elsif !File.exist?(path)
          return false
        end
        true
      end

      def path_relative_to_source(dir, path)
        File.join(INCLUDES_DIR, path.sub(Regexp.new("^#{dir}"), ""))
      end

      def realpath_prefixed_with?(path, dir)
        File.exist?(path) && File.realpath(path).start_with?(dir)
      end

      def blank?
        false
      end

      # This method allows to modify the file content by inheriting from the class.
      def source(file, context)
        File.read(file, file_read_opts(context))
      end
    end

end

Liquid::Template.register_tag('include_if_exists', Jekyll::IncludeIfExists)