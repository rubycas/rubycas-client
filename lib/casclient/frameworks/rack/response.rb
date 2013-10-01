module CASClient
  module Frameworks
    module Rack

      class Response
        attr_reader :user, :extra_attributes, :errors, :ticket

        def initialize(user, extra_attributes, errors: [], ticket: nil)
          @user, @extra_attributes, @errors, @ticket = user, extra_attributes, errors, ticket
          @errors = [@errors] unless @errors.is_a?(Array)
        end

        def attributes
          @extra_attributes
        end

        def valid?
          !@user.nil? and @errors.empty?
        end

        def to_s
          "User: #{@user.nil? ? 'nil' : @user}, Attributes: #{@extra_attributes}, Valid?: #{valid?}, Errors: #{@errors}"
        end

        def to_hash # mimic a minimal Rails session hash
          {
            cas_user: @user,
            cas_extra_attributes: @extra_attributes,
            errors: @errors,
            ticket: @ticket,
          }
        end

        def error_messages
          @errors.join(", ")
        end
      end
    end
  end
end
