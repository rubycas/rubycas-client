module CASClient
  module Frameworks
    module Rack

      class Response
        attr_reader :user, :extra_attributes, :errors

        def initialize(user = nil, extra_attributes = nil, *errors)
          @user, @extra_attributes, @errors = user, extra_attributes, errors
        end

        def attributes
          extra_attributes
        end

        def valid?
          @errors.empty?
        end

        def to_s
          "User: #{@user}, Attributes: [#{@extra_attributes}], Valid?: #{valid?}, Errors: #{@errors}"
        end

        def error_messages
          @errors.join(", ")
        end
      end
    end
  end
end
