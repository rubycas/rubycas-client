module CASClient
  module Frameworks
    module Rack

      class Response
        attr_reader :user, :extra_attributes, :errors, :ticket

        def initialize(user, extra_attributes, *errors, ticket: nil)
          @user, @extra_attributes, @errors, @ticket = user, extra_attributes, errors, ticket
        end

        def attributes
          extra_attributes
        end

        def valid?
          !@user.nil? and @errors.empty?
        end

        def to_s
          if valid?
            "User: #{@user}, Attributes: #{@extra_attributes}, Valid?: #{valid?}, Errors: #{@errors}"
          else
            "Errors: #{@errors}"
          end
        end

        def to_hash # mimic a minimal Rails session hash
          if valid?
            {
              cas_user: @user,
              cas_extra_attributes: @extra_attributes,
              ticket: @ticket
            }
          else
            { errors: @errors }
          end
        end

        def error_messages
          @errors.join(", ")
        end
      end
    end
  end
end
