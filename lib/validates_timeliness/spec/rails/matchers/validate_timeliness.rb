module Spec
  module Rails
    module Matchers
      class ValidateTimeliness
   
        VALIDITY_TEST_VALUES = {
          :date     => {:pass => '2000-01-01', :fail => '2000-01-32'},
          :time     => {:pass => '12:00',      :fail => '25:00'},
          :datetime => {:pass => '2000-01-01 00:00:00', :fail => '2000-01-32 00:00:00'}
        }

        OPTION_TEST_SETTINGS = {
          :before       => { :method => :-, :modify_on => :valid },
          :after        => { :method => :+, :modify_on => :valid },
          :on_or_before => { :method => :+, :modify_on => :invalid },
          :on_or_after  => { :method => :-, :modify_on => :invalid }
        }

        def initialize(attribute, options)
          @expected, @options = attribute, options
          @validator = ValidatesTimeliness::Validator.new(options)
        end

        def matches?(record)
          @record = record
          @type = @options[:type]
          
          valid = test_validity

          valid = test_option(:before) if @options[:before] && valid
          valid = test_option(:after) if @options[:after] && valid
          
          valid = test_option(:on_or_before) if @options[:on_or_before] && valid
          valid = test_option(:on_or_after) if @options[:on_or_after] && valid

          valid = test_between if @options[:between] && valid

          return valid
        end
      
        def failure_message
          "expected model to validate #{@type} attribute #{@expected.inspect} with #{@last_failure}"
        end
        
        def negative_failure_message
          "expected not to validate #{@type} attribute #{@expected.inspect}"
        end
        
        def description
          "have validated #{@type} attribute #{@expected.inspect}"
        end
        
       private
       
        def test_validity
          invalid_value = VALIDITY_TEST_VALUES[@type][:fail]
          valid_value   = parse_and_cast(VALIDITY_TEST_VALUES[@type][:pass])
          error_matching(invalid_value, "invalid_#{@type}".to_sym) &&
            no_error_matching(valid_value, "invalid_#{@type}".to_sym)
        end

        def test_option(option)
          settings = OPTION_TEST_SETTINGS[option]
          boundary = parse_and_cast(@options[option])
          
          method = settings[:method]

          valid_value, invalid_value = if settings[:modify_on] == :valid
            [ boundary.send(method, 1), boundary ]
          else
            [ boundary, boundary.send(method, 1) ]
          end
          
          error_matching(invalid_value, option) && 
            no_error_matching(valid_value, option)
        end

        def test_before
          before = parse_and_cast(@options[:before])

          error_matching(before - 1, :before) && 
            no_error_matching(before, :before)
        end

        def test_between
          between = parse_and_cast(@options[:between]) 
          
          error_matching(between.first - 1, :between) && 
            error_matching(between.last + 1, :between) && 
            no_error_matching(between.first, :between) &&
            no_error_matching(between.last, :between)
        end
       
        def parse_and_cast(value)
          value = @validator.send(:restriction_value, value, @record)
          @validator.send(:type_cast_value, value)
        end

        def error_matching(value, option)
          match = error_message_for(option)
          @record.send("#{@expected}=", value)
          @record.valid?
          errors = @record.errors.on(@expected)
          pass = [ errors ].flatten.any? {|error| /#{match}/ === error }
          @last_failure = "error matching '#{match}' when value is #{format_value(value)}" unless pass
          pass
        end
        
        def no_error_matching(value, option)
          pass = !error_matching(value, option)
          unless pass
            error = error_message_for(option)
            @last_failure = "no error matching '#{error}' when value is #{format_value(value)}"
          end
          pass
        end

        def error_message_for(option)
          msg = @validator.send(:error_messages)[option]
          restriction = @validator.send(:restriction_value, @validator.configuration[option], @record)

          if restriction 
            restriction = [restriction] unless restriction.is_a?(Array)
            restriction.map! {|r| @validator.send(:type_cast_value, r) }
            interpolate = @validator.send(:interpolation_values, option, restriction )
            # get I18n message if defined and has interpolation keys in msg
            if defined?(I18n) && msg.match(/\{\{/)
              msg = @record.errors.generate_message(@expected, option, interpolate)
            else
              msg = msg % interpolate
            end
          end 
          msg
        end
        
        def format_value(value)
          return value if value.is_a?(String)
          value.strftime(ValidatesTimeliness::Validator.error_value_formats[@type])
        end
      end

      def validate_date(attribute, options={})
        options[:type] = :date
        ValidateTimeliness.new(attribute, options)
      end

      def validate_time(attribute, options={})
        options[:type] = :time
        ValidateTimeliness.new(attribute, options)
      end

      def validate_datetime(attribute, options={})
        options[:type] = :datetime
        ValidateTimeliness.new(attribute, options)
      end
    end
  end
end
